import 'package:flutter/material.dart';
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
        _error = 'Failed to translate: $e';
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
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Translator',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
            ),

            // Language Selector Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  border: Border.all(color: AppColors.borderLight, width: AppTokens.borderMedium),
                  boxShadow: AppTokens.shadow(level: 1),
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
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.brandSoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.swap_horiz,
                          color: AppColors.brand,
                        ),
                      ),
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
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Input TextField
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                        border: Border.all(color: AppColors.border, width: AppTokens.borderMedium),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _inputController,
                            maxLines: 4,
                            minLines: 3,
                            decoration: const InputDecoration(
                              hintText: 'Enter text to translate...',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              fillColor: Colors.transparent,
                            ),
                            onSubmitted: (_) => _translate(),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: AppColors.cherryGradient,
                                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                                ),
                                child: ElevatedButton(
                                  onPressed: _isTranslating ? null : _translate,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
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
                        ),
                      ),

                    // Result Area
                    if (_translatedText != null) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.brandSoft,
                          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                          border: Border.all(color: AppColors.brand.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Translation',
                                  style: TextStyle(
                                    color: AppColors.brandDeep,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 20),
                                      color: AppColors.brand,
                                      onPressed: () {
                                        // Copy to clipboard
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _translatedText!,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: AppColors.text,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_history.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      const Text(
                        'Recent Translations',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._history.map((entry) => _buildHistoryItem(entry)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelector({
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
          items: AppConstants.supportedLanguages.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Text(
                entry.value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildHistoryItem(_TranslationEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${AppConstants.supportedLanguages[entry.from]} → ${AppConstants.supportedLanguages[entry.to]}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            entry.source,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSoft,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            entry.translated,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
        ],
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
