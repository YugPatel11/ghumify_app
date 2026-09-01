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
  final List<_TranslationEntry> _history = [];

  Future<void> _translate() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

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
        _error = e is TranslationException
            ? e.message
            : 'Translation failed. Please check your connection.';
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
        content: const Text('Copied to clipboard'),
        backgroundColor: AppColors.brand,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Translator'),
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTokens.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Language Selector ──
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                border: Border.all(color: AppColors.border),
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
                  GestureDetector(
                    onTap: _swapLanguages,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.brandSoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.swap_horiz, color: AppColors.brand, size: 20),
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

            const SizedBox(height: AppTokens.lg),

            // ── Input ──
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppTokens.md),
                    child: TextField(
                      controller: _inputController,
                      maxLines: 4,
                      minLines: 3,
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: const InputDecoration(
                        hintText: 'Enter text to translate...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                      ),
                      onSubmitted: (_) => _translate(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppTokens.md, 0, AppTokens.md, AppTokens.md),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: _isTranslating ? null : _translate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                          ),
                          elevation: 0,
                        ),
                        child: _isTranslating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Translate', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppTokens.md),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),

            // ── Result ──
            if (_translatedText != null) ...[
              const SizedBox(height: AppTokens.lg),
              Container(
                padding: const EdgeInsets.all(AppTokens.lg),
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
                          'TRANSLATION',
                          style: TextStyle(
                            color: AppColors.brand,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _copyToClipboard(_translatedText!),
                          child: const Icon(Icons.copy, size: 18, color: AppColors.brand),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.md),
                    Text(
                      _translatedText!,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ],

            // ── History ──
            if (_history.isNotEmpty) ...[
              const SizedBox(height: AppTokens.xl),
              Text(
                'Recent',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppTokens.md),
              ..._history.map((entry) => _buildHistoryItem(entry)),
            ],
            const SizedBox(height: 80),
          ],
        ),
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
        icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted, size: 18),
        dropdownColor: AppColors.card,
        alignment: alignRight ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
        items: AppConstants.supportedLanguages.entries.map((entry) {
          return DropdownMenuItem<String>(
            value: entry.key,
            child: Text(
              entry.value,
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text, fontSize: 14),
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
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text, fontSize: 14),
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
      padding: const EdgeInsets.only(bottom: AppTokens.sm),
      child: Container(
        padding: const EdgeInsets.all(AppTokens.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${AppConstants.supportedLanguages[entry.from]} → ${AppConstants.supportedLanguages[entry.to]}'.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                GestureDetector(
                  onTap: () => _copyToClipboard(entry.translated),
                  child: const Icon(Icons.copy, size: 14, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.sm),
            Text(
              entry.source,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
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
