import 'package:equatable/equatable.dart';

import '../utils/tag_normalizer.dart';

/// Represents a unified tag with a canonical name and display label.
class ContentTag extends Equatable {
  ContentTag({
    required this.canonicalName,
    required this.displayName,
    Set<String>? aliases,
  }) : aliases = aliases == null
           ? {canonicalName}
           : {...aliases, canonicalName};

  final String canonicalName;
  final String displayName;
  final Set<String> aliases;

  bool matches(String raw) {
    final normalized = TagNormalizer.normalize(raw);
    return normalized.isNotEmpty && aliases.contains(normalized);
  }

  ContentTag merge(ContentTag other) {
    final mergedAliases = {...aliases, ...other.aliases};
    return ContentTag(
      canonicalName: canonicalName,
      displayName: _preferDisplay(displayName, other.displayName),
      aliases: mergedAliases,
    );
  }

  static String _preferDisplay(String current, String next) {
    final trimmedCurrent = current.trim();
    final trimmedNext = next.trim();
    if (trimmedCurrent.isEmpty) {
      return trimmedNext;
    }
    if (trimmedNext.isEmpty) {
      return trimmedCurrent;
    }
    final canonicalCurrent = TagNormalizer.normalize(trimmedCurrent);
    final canonicalNext = TagNormalizer.normalize(trimmedNext);
    final currentLooksCanonical = canonicalCurrent == trimmedCurrent;
    final nextLooksCanonical = canonicalNext == trimmedNext;
    if (canonicalCurrent == canonicalNext) {
      if (!currentLooksCanonical && nextLooksCanonical) {
        return trimmedCurrent;
      }
      if (currentLooksCanonical && !nextLooksCanonical) {
        return trimmedNext;
      }
    }
    return trimmedCurrent;
  }

  factory ContentTag.fromLabels({
    required String primary,
    String? display,
    Iterable<String> alternatives = const [],
  }) {
    var canonical = TagNormalizer.normalize(primary);
    final normalizedAlternatives = alternatives
        .map(TagNormalizer.normalize)
        .where((alias) => alias.isNotEmpty)
        .toSet();
    final defaultDisplay = (display != null && display.trim().isNotEmpty)
        ? display.trim()
        : primary;
    if (canonical.isEmpty) {
      canonical = TagNormalizer.normalize(defaultDisplay);
    }
    normalizedAlternatives.add(canonical);
    return ContentTag(
      canonicalName: canonical,
      displayName: defaultDisplay.trim(),
      aliases: normalizedAlternatives,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'canonical': canonicalName,
      'display': displayName,
      'aliases': aliases.toList(),
    };
  }

  factory ContentTag.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return ContentTag.fromLabels(primary: '');
    }
    final canonical = json['canonical'] as String? ?? '';
    final display = json['display'] as String? ?? canonical;
    final aliasList = (json['aliases'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toSet();
    if (canonical.isEmpty) {
      return ContentTag.fromLabels(primary: display);
    }
    return ContentTag(
      canonicalName: canonical,
      displayName: display,
      aliases: aliasList.isEmpty ? {canonical} : {...aliasList, canonical},
    );
  }

  @override
  List<Object?> get props => [canonicalName, displayName, aliases];
}
