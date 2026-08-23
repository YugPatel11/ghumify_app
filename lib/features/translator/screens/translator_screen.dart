import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/translation_service.dart';

class TranslatorScreen extends StatefulWidget {
  const TranslatorScreen({super.key});

  @override
  State<TranslatorScreen> createState() => _TranslatorScreenState();
}

class _TranslatorScreenState extends State<TranslatorScreen> {
  final TranslationService _translationService = TranslationService();
  final TextEditingController _inputController = TextEditingController();

  String _sourceLanguage = 'en';
  String _targetLanguage = 'hi';
  String? _translatedText;
  bool _isTranslating = false;
  String? _error;

  // Recent translations
  final List<_TranslationEntry> _history = [];

  Future<void> _translate() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    
    // Hide keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      _isTranslating = true;
      _error = null;
    });

    try {
      final result = await _translationService.translate(
        text: text,
        targetLanguage: _targetLanguage,
        sourceLanguage: _sourceLanguage,
      );

      setState(() {
        _translatedText = result;
        _isTranslating = false;
        _history.insert(
          0,
          _TranslationEntry(
            source: text,
            translated: result,
            from: _sourceLanguage,
            to: _targetLanguage,
          ),
        );
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to translate. Please try again.';
        _isTranslating = false;
      });
    }
  }

  void _swapLanguages() {
    setState(() {
      final temp = _sourceLanguage;
      _sourceLanguage = _targetLanguage;
      _targetLanguage = temp;
      _translatedText = null;
      _inputController.clear();
    });
  }
  
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Copied to clipboard', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.brand,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text(
          'TRANSLATOR',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.text,
      ),
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1528181304800-259b08848526?q=80&w=2000&auto=format&fit=crop', // Minimal temple architecture
              fit: BoxFit.cover,
            ),
          ),
          // Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.5),
                    Colors.white.withOpacity(0.8),
                    AppColors.bg,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Language Selector Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.glassWhite,
                          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                          border: Border.all(color: AppColors.borderGlass),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildLanguageSelector(
                                value: _sourceLanguage,
                                onChanged: (val) {
                                  if (val != null) setState(() => _sourceLanguage = val);
                                },
                              ),
                            ),
                            IconButton(
                              onPressed: _swapLanguages,
                              icon: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.glassWhiteLight,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.swap_horiz, color: AppColors.brand),
                              ),
                            ),
                            Expanded(
                              child: _buildLanguageSelector(
                                value: _targetLanguage,
                                onChanged: (val) {
                                  if (val != null) setState(() => _targetLanguage = val);
                                },
                                alignRight: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppTokens.lg),

                // Input Area
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Input TextField
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppTokens.radiusXl),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.glassWhiteLight,
                                borderRadius: BorderRadius.circular(AppTokens.radiusXl),
                                border: Border.all(color: AppColors.borderGlass),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(AppTokens.lg),
                                    child: TextField(
                                      controller: _inputController,
                                      maxLines: 4,
                                      minLines: 3,
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        height: 1.5,
                                        color: AppColors.text,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Enter text to translate...',
                                        hintStyle: TextStyle(color: AppColors.textSoft),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        fillColor: Colors.transparent,
                                      ),
                                      onSubmitted: (_) => _translate(),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(AppTokens.md),
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: ElevatedButton(
                                        onPressed: _isTranslating ? null : _translate,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.brand,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 32,
                                            vertical: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: _isTranslating
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Text(
                                                'Translate',
                                                style: TextStyle(fontWeight: FontWeight.w700),
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: AppColors.error),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        // Result Area
                        if (_translatedText != null) ...[
                          const SizedBox(height: AppTokens.xl),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppTokens.radiusXl),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.all(AppTokens.xl),
                                decoration: BoxDecoration(
                                  color: AppColors.glassWhiteLight,
                                  borderRadius: BorderRadius.circular(AppTokens.radiusXl),
                                  border: Border.all(color: AppColors.borderGlass),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'TRANSLATION',
                                          style: TextStyle(
                                            color: AppColors.brand,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () => _copyToClipboard(_translatedText!),
                                          icon: const Icon(Icons.copy, size: 20, color: AppColors.brand),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppTokens.md),
                                    Text(
                                      _translatedText!,
                                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                            color: AppColors.text,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],

                        if (_history.isNotEmpty) ...[
                          const SizedBox(height: AppTokens.xxl),
                          Text(
                            'Recent Translations',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppTokens.lg),
                          ..._history.map((entry) => _buildHistoryItem(entry)),
                        ],
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector({
    required String value,
    required ValueChanged<String?> onChanged,
    bool alignRight = false,
  }) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSoft),
        dropdownColor: AppColors.card,
        alignment: alignRight ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
        items: AppConstants.supportedLanguages.entries.map((entry) {
          return DropdownMenuItem<String>(
            value: entry.key,
            child: Text(
              entry.value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
              textAlign: alignRight ? TextAlign.right : TextAlign.left,
            ),
          );
        }).toList(),
        onChanged: onChanged,
        selectedItemBuilder: (context) {
          return AppConstants.supportedLanguages.entries.map((entry) {
            return Container(
              alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
              child: Text(
                entry.value,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList();
        },
      ),
    );
  }

  Widget _buildHistoryItem(_TranslationEntry entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.md),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(AppTokens.lg),
            decoration: BoxDecoration(
              color: AppColors.glassWhiteLight,
              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              border: Border.all(color: AppColors.borderGlass),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${AppConstants.supportedLanguages[entry.from]} → ${AppConstants.supportedLanguages[entry.to]}'.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _copyToClipboard(entry.translated),
                      icon: Icon(Icons.copy, size: 14, color: AppColors.textMuted),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.sm),
                Text(
                  entry.source,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSoft,
                  ),
                ),
                const SizedBox(height: AppTokens.sm),
                Text(
                  entry.translated,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TranslationEntry {
  final String source;
  final String translated;
  final String from;
  final String to;

  _TranslationEntry({
    required this.source,
    required this.translated,
    required this.from,
    required this.to,
  });
}
