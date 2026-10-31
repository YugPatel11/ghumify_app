import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_settings_provider.dart';
import '../services/translation_service.dart';

/// Clean, drop-in replacement for [Text] that displays translated text
/// based on the user's preferred language in [AppSettingsProvider].
///
/// If translation is already cached, it renders instantly with ZERO flicker.
/// If translation is loading, it displays the original English text and
/// smoothly updates once ready.
class TranslatedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;

  const TranslatedText(
    this.text, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final targetLang = settings.language;

    // English requires zero API calls or async builders
    if (TranslationService.isEnglish(targetLang)) {
      return Text(
        text,
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
      );
    }

    final cached = TranslationService.instance.getCached(text, targetLang: targetLang);
    if (cached != null) {
      return Text(
        cached,
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
      );
    }

    return FutureBuilder<String>(
      future: TranslationService.instance.translateText(text, targetLang: targetLang),
      initialData: text,
      builder: (context, snapshot) {
        final displayText = snapshot.data ?? text;
        return Text(
          displayText,
          style: style,
          strutStyle: strutStyle,
          textAlign: textAlign,
          textDirection: textDirection,
          locale: locale,
          softWrap: softWrap,
          overflow: overflow,
          textScaler: textScaler,
          maxLines: maxLines,
          semanticsLabel: semanticsLabel,
          textWidthBasis: textWidthBasis,
          textHeightBehavior: textHeightBehavior,
        );
      },
    );
  }
}

/// Concise shorthand typedef for [TranslatedText]
typedef Tr = TranslatedText;

/// BuildContext helper extension for localized string resolution
extension TranslateContextExtension on BuildContext {
  /// Return cached translation string, or original English if translating
  String tr(String text) {
    final settings = watch<AppSettingsProvider>();
    final targetLang = settings.language;
    if (TranslationService.isEnglish(targetLang)) return text;

    final cached = TranslationService.instance.getCached(text, targetLang: targetLang);
    if (cached != null) return cached;

    // Trigger async fetch in background
    TranslationService.instance.translateText(text, targetLang: targetLang);
    return text;
  }
}

/// String extension for rendering [TranslatedText] inline
extension TranslateStringExtension on String {
  Widget tr({
    Key? key,
    TextStyle? style,
    TextAlign? textAlign,
    TextOverflow? overflow,
    int? maxLines,
    bool? softWrap,
  }) {
    return TranslatedText(
      this,
      key: key,
      style: style,
      textAlign: textAlign,
      overflow: overflow,
      maxLines: maxLines,
      softWrap: softWrap,
    );
  }
}
