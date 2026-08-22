import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/translation_service.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_background.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'TRANSLATOR',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: PremiumBackground(
        imageUrl: 'https://images.unsplash.com/photo-1528181304800-259b08848526?q=80&w=2000&auto=format&fit=crop', // Minimal temple architecture
        imageHeight: 300,
        overlayOpacity: 0.5,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Language Selector Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
                child: PremiumCard(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
                        icon: const Icon(Icons.swap_horiz, color: AppColors.textMuted),
                      ),
                      Expanded(
                        child: _buildLanguageSelector(
                          value: _targetLanguage,
                          onChanged: (val) {
                            if (val != null) setState(() => _targetLanguage = val);
                          },
                        ),
                      ),
                    ],
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
                      PremiumCard(
                        padding: EdgeInsets.zero,
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
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Enter text to translate...',
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
                                    backgroundColor: AppColors.text, // Charcoal
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 16,
                                    ),
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
                        Container(
                          padding: const EdgeInsets.all(AppTokens.xl),
                          decoration: BoxDecoration(
                            color: AppColors.brandSoft,
                            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                            border: Border.all(color: AppColors.brandDeep.withOpacity(0.1)),
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
                                      color: AppColors.brandDeep,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  Icon(Icons.copy, size: 18, color: AppColors.brandDeep),
                                ],
                              ),
                              const SizedBox(height: AppTokens.md),
                              Text(
                                _translatedText!,
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      color: AppColors.brandDeep,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (_history.isNotEmpty) ...[
                        const SizedBox(height: AppTokens.xxl),
                        Text(
                          'Recent',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppTokens.md),
                        ..._history.map((entry) => _buildHistoryItem(entry)),
                      ],
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageSelector({
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
        items: AppConstants.supportedLanguages.entries.map((entry) {
          return DropdownMenuItem<String>(
            value: entry.key,
            child: Text(
              entry.value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildHistoryItem(_TranslationEntry entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.md),
      child: PremiumCard(
        padding: const EdgeInsets.all(AppTokens.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${AppConstants.supportedLanguages[entry.from]} → ${AppConstants.supportedLanguages[entry.to]}'.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: AppTokens.sm),
            Text(
              entry.source,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSoft,
              ),
            ),
            const SizedBox(height: AppTokens.xs),
            Text(
              entry.translated,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
