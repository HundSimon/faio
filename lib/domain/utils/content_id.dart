import '../models/content_item.dart';

int? parsePrefixedNumericId(String rawId) {
  final trimmed = rawId.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final parts = trimmed.split(':');
  final candidate = parts.isNotEmpty ? parts.last : trimmed;
  return int.tryParse(candidate);
}

int? parseContentNumericId(FaioContent content) {
  return parsePrefixedNumericId(content.id);
}
