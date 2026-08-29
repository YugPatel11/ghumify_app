import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/models/chat_message_model.dart';
import '../../../core/models/itinerary_model.dart';
import '../../../core/models/multi_day_itinerary_model.dart';
import '../../../core/services/gemini_service.dart';
import 'chat_bubble.dart';

/// AI Chat bottom sheet for itinerary modification and questions.
///
/// Understands the user's current itinerary and maintains conversation context.
/// Can return modified itineraries when the user requests changes.
class ItineraryChatSheet extends StatefulWidget {
  /// Current single-day itinerary (provide this OR multiDayItinerary)
  final ItineraryModel? itinerary;

  /// Current multi-day itinerary (provide this OR itinerary)
  final MultiDayItineraryModel? multiDayItinerary;

  /// Callback when AI suggests itinerary changes and user accepts
  final void Function(ItineraryModel updatedItinerary)? onItineraryUpdated;

  /// Callback when AI suggests multi-day itinerary changes and user accepts
  final void Function(MultiDayItineraryModel updatedItinerary)?
      onMultiDayItineraryUpdated;

  const ItineraryChatSheet({
    super.key,
    this.itinerary,
    this.multiDayItinerary,
    this.onItineraryUpdated,
    this.onMultiDayItineraryUpdated,
  });

  @override
  State<ItineraryChatSheet> createState() => _ItineraryChatSheetState();
}

class _ItineraryChatSheetState extends State<ItineraryChatSheet> {
  final GeminiService _geminiService = GeminiService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<ChatMessageModel> _messages = [];
  bool _isLoading = false;
  String? _chatSessionId;

  static const _suggestedQuestions = [
    '🔄 Replace a place',
    '➕ Add a food stop',
    '⏰ I have less time',
    '😌 Make it more relaxed',
    '📸 Best photo spots?',
    '🍽️ Where to eat?',
  ];

  @override
  void initState() {
    super.initState();
    _chatSessionId = _getItineraryId();
    _loadChatHistory();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _getItineraryId() {
    if (widget.itinerary != null) return widget.itinerary!.id;
    if (widget.multiDayItinerary != null) return widget.multiDayItinerary!.id;
    return 'unknown';
  }

  bool get _isMultiDay => widget.multiDayItinerary != null;

  Map<String, dynamic> get _currentItineraryMap {
    if (widget.multiDayItinerary != null) {
      return widget.multiDayItinerary!.toMap();
    }
    if (widget.itinerary != null) {
      return widget.itinerary!.toMap();
    }
    return {};
  }

  /// Load chat history from SharedPreferences
  Future<void> _loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'chat_$_chatSessionId';
      final stored = prefs.getString(key);
      if (stored != null) {
        final session = ChatSessionModel.fromMap(
          json.decode(stored) as Map<String, dynamic>,
        );
        setState(() {
          _messages = session.messages;
        });
        _scrollToBottom();
      }
    } catch (_) {
      // First time — no history
    }
  }

  /// Save chat history to SharedPreferences
  Future<void> _saveChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'chat_$_chatSessionId';
      final session = ChatSessionModel(
        id: _chatSessionId!,
        itineraryId: _chatSessionId!,
        messages: _messages,
      );
      await prefs.setString(key, json.encode(session.toMap()));
    } catch (_) {
      // Silent fail on save
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMessage = ChatMessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      content: text.trim(),
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      final response = await _geminiService.chatAboutItinerary(
        userMessage: text.trim(),
        currentItinerary: _currentItineraryMap,
        chatHistory: _messages,
        isMultiDay: _isMultiDay,
      );

      setState(() {
        _messages.add(response);
        _isLoading = false;
      });
      _scrollToBottom();
      _saveChatHistory();
    } catch (e) {
      setState(() {
        _messages.add(ChatMessageModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          role: 'assistant',
          content: 'Error: ${e.toString()}',
        ));
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _applyItineraryUpdate(ChatMessageModel message) {
    if (message.updatedItinerary == null) return;

    try {
      if (_isMultiDay && widget.onMultiDayItineraryUpdated != null) {
        final updated =
            MultiDayItineraryModel.fromMap(message.updatedItinerary!);
        widget.onMultiDayItineraryUpdated!(updated);
      } else if (widget.onItineraryUpdated != null) {
        final data = message.updatedItinerary!;
        final stops = (data['stops'] as List? ?? [])
            .map((s) => ItineraryStop.fromMap(s as Map<String, dynamic>))
            .toList();

        final updated = widget.itinerary!.copyWith(
          stops: stops,
          aiSummary: data['aiSummary'] as String?,
          whatToCarry: data['whatToCarry'] != null
              ? List<String>.from(data['whatToCarry'])
              : null,
          weatherSummary: data['weatherSummary'] as String?,
        );
        widget.onItineraryUpdated!(updated);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Itinerary updated!',
                style: TextStyle(color: Colors.white)),
            backgroundColor: AppColors.brand,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not apply changes: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTokens.radiusXl),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.glassWhiteLight, // Frosted light glass
                border: Border(
                  top: BorderSide(color: AppColors.borderGlass, width: 1),
                ),
              ),
              child: Column(
                children: [
                  // ── Handle Bar ──
                  _buildHandle(),

                  // ── Header ──
                  _buildHeader(),

                  Divider(height: 1, color: AppColors.borderLight),

                  // ── Messages ──
                  Expanded(
                    child: _messages.isEmpty
                        ? _buildEmptyState()
                        : _buildMessageList(scrollController),
                  ),

                  // ── Loading indicator ──
                  if (_isLoading) _buildTypingIndicator(),

                  Divider(height: 1, color: AppColors.borderLight),

                  // ── Suggestion chips (only when empty or few messages) ──
                  if (_messages.length < 3) _buildSuggestionChips(),

                  // ── Input ──
                  _buildInputBar(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        width: 48,
        height: 5,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTokens.lg, 4, AppTokens.md, AppTokens.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.brand.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              border: Border.all(color: AppColors.brand.withOpacity(0.5)),
            ),
            child: const Icon(Icons.auto_awesome, size: 20, color: AppColors.brand),
          ),
          const SizedBox(width: AppTokens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trip Assistant',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppColors.text,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Ask questions or modify your itinerary',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSoft,
                  ),
                ),
              ],
            ),
          ),
          if (_messages.isNotEmpty)
            IconButton(
              onPressed: () async {
                setState(() => _messages.clear());
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('chat_$_chatSessionId');
              },
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.glassWhite,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline, size: 18),
              ),
              tooltip: 'Clear chat',
              color: AppColors.textMuted,
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.glassWhiteLight,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderGlass),
              ),
              child: Icon(
                Icons.forum_outlined,
                size: 48,
                color: AppColors.textSoft,
              ),
            ),
            const SizedBox(height: AppTokens.lg),
            const Text(
              'Ask me anything about your trip',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: AppTokens.sm),
            Text(
              'I can answer questions, suggest changes, or modify your itinerary entirely.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSoft,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(ScrollController sheetScrollController) {
    // We attach the sheetScrollController so we can scroll the entire sheet when reading messages
    return ListView.builder(
      controller: sheetScrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.md,
        vertical: AppTokens.lg,
      ),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return ChatBubble(
          message: message,
          onApplyChanges: message.hasItineraryUpdate
              ? () => _applyItineraryUpdate(message)
              : null,
        );
      },
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.lg,
        vertical: AppTokens.md,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.glassWhite,
              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              border: Border.all(color: AppColors.borderGlass),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.brand,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Thinking...',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSoft,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChips() {
    return Container(
      height: 60,
      alignment: Alignment.center,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.md, vertical: 12),
        itemCount: _suggestedQuestions.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: AppTokens.sm),
            child: ActionChip(
              label: Text(
                _suggestedQuestions[index],
                style: const TextStyle(fontSize: 13, color: AppColors.text, fontWeight: FontWeight.w500),
              ),
              backgroundColor: AppColors.glassWhiteLight,
              side: BorderSide(color: AppColors.borderGlass),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              ),
              onPressed: () {
                _sendMessage(_suggestedQuestions[index]);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.lg,
          AppTokens.sm,
          AppTokens.sm,
          AppTokens.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.glassWhite,
                  borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                  border: Border.all(color: AppColors.borderGlass),
                ),
                child: TextField(
                  controller: _messageController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: 'Ask about your trip...',
                    hintStyle: TextStyle(color: AppColors.textSoft, fontSize: 15),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                  style: const TextStyle(fontSize: 15, color: AppColors.text),
                  textInputAction: TextInputAction.send,
                  onSubmitted: _sendMessage,
                  enabled: !_isLoading,
                ),
              ),
            ),
            const SizedBox(width: AppTokens.sm),
            Container(
              decoration: const BoxDecoration(
                color: AppColors.brand,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                padding: const EdgeInsets.all(12),
                onPressed: _isLoading
                    ? null
                    : () => _sendMessage(_messageController.text),
                icon: const Icon(Icons.send_rounded, size: 20),
                color: Colors.white,
                disabledColor: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
