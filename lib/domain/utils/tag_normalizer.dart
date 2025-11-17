class TagNormalizer {
  const TagNormalizer._();

  static final RegExp _separatorPattern = RegExp(r'[\s\-]+');
  static final RegExp _underscorePattern = RegExp(r'_+');

  /// Normalizes any tag string into a canonical lowercase token.
  static String normalize(String? raw) {
    if (raw == null) {
      return '';
    }
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final lowered = trimmed.toLowerCase();
    final replaced = lowered.replaceAll(_separatorPattern, '_');
    final collapsed = replaced.replaceAll(_underscorePattern, '_');
    final sanitized = collapsed.trim();
    if (sanitized == '_') {
      return '';
    }
    return sanitized;
  }
}
