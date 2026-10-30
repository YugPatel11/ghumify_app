export interface MaskedText {
  masked: string;
  tokens: Map<string, string>;
}

// Protected patterns: ICU placeholders {name}, {count}, HTML tags, URLs, emails, brand "Ghumify"
const PLACEHOLDER_REGEX = /\{[a-zA-Z0-9_]+\}/g;
const HTML_TAG_REGEX = /<[^>]+>/g;
const URL_REGEX = /https?:\/\/[^\s$.?#].[^\s]*/gi;
const EMAIL_REGEX = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g;
const BRAND_REGEX = /\bGhumify\b/g;

export function maskPlaceholders(text: string): MaskedText {
  const tokens = new Map<string, string>();
  let counter = 0;

  let masked = text;

  // Protect brand name first
  masked = masked.replace(BRAND_REGEX, () => {
    const token = `__GHUMIFY_BRAND_${counter++}__`;
    tokens.set(token, 'Ghumify');
    return token;
  });

  // Protect URLs
  masked = masked.replace(URL_REGEX, (url) => {
    const token = `__URL_${counter++}__`;
    tokens.set(token, url);
    return token;
  });

  // Protect emails
  masked = masked.replace(EMAIL_REGEX, (email) => {
    const token = `__EMAIL_${counter++}__`;
    tokens.set(token, email);
    return token;
  });

  // Protect HTML tags
  masked = masked.replace(HTML_TAG_REGEX, (tag) => {
    const token = `__TAG_${counter++}__`;
    tokens.set(token, tag);
    return token;
  });

  // Protect ICU placeholders like {name}, {count}, {hours}
  masked = masked.replace(PLACEHOLDER_REGEX, (ph) => {
    const token = `__PH_${counter++}__`;
    tokens.set(token, ph);
    return token;
  });

  return { masked, tokens };
}

export function restorePlaceholders(translated: string, tokens: Map<string, string>): { text: string; intact: boolean } {
  let restored = translated;
  let intact = true;

  for (const [token, original] of tokens.entries()) {
    // Sometimes translation APIs add spaces inside tokens, e.g., "__ PH _0__"
    const flexiblePattern = new RegExp(token.replace(/_/g, '[_\\s]*'), 'gi');
    if (flexiblePattern.test(restored)) {
      restored = restored.replace(flexiblePattern, original);
    } else {
      // Token missing or severely corrupted
      intact = false;
    }
  }

  return { text: restored, intact };
}
