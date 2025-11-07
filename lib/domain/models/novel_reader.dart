import 'package:equatable/equatable.dart';

class NovelReaderSettings extends Equatable {
  const NovelReaderSettings({
    this.fontFamily = 'sans',
    this.fontSize = 18.0,
    this.lineHeight = 1.6,
    this.paragraphSpacing = 12.0,
    this.themeId = 'light',
  });

  final String fontFamily;
  final double fontSize;
  final double lineHeight;
  final double paragraphSpacing;
  final String themeId;

  NovelReaderSettings copyWith({
    String? fontFamily,
    double? fontSize,
    double? lineHeight,
    double? paragraphSpacing,
    String? themeId,
  }) {
    return NovelReaderSettings(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      themeId: themeId ?? this.themeId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fontFamily': fontFamily,
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'paragraphSpacing': paragraphSpacing,
      'themeId': themeId,
    };
  }

  factory NovelReaderSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const NovelReaderSettings();
    }
    return NovelReaderSettings(
      fontFamily: json['fontFamily'] as String? ?? 'sans',
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 18.0,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.6,
      paragraphSpacing:
          (json['paragraphSpacing'] as num?)?.toDouble() ?? 12.0,
      themeId: json['themeId'] as String? ?? 'light',
    );
  }

  @override
  List<Object?> get props =>
      [fontFamily, fontSize, lineHeight, paragraphSpacing, themeId];
}

class NovelReadingProgress extends Equatable {
  const NovelReadingProgress({
    required this.novelId,
    required this.relativeOffset,
    required this.updatedAt,
  });

  final int novelId;
  final double relativeOffset;
  final DateTime updatedAt;

  bool get isCompleted => relativeOffset >= 0.98;

  Map<String, dynamic> toJson() {
    return {
      'novelId': novelId,
      'relativeOffset': relativeOffset,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory NovelReadingProgress.fromJson(
    int novelId,
    Map<String, dynamic>? json,
  ) {
    if (json == null) {
      return NovelReadingProgress(
        novelId: novelId,
        relativeOffset: 0,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
    }
    final updatedAtRaw = json['updatedAt'] as String? ?? '';
    final updatedAt = DateTime.tryParse(updatedAtRaw) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return NovelReadingProgress(
      novelId: novelId,
      relativeOffset: (json['relativeOffset'] as num?)?.toDouble() ?? 0,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [novelId, relativeOffset, updatedAt];

  NovelReadingProgress copyWith({
    double? relativeOffset,
    DateTime? updatedAt,
  }) {
    return NovelReadingProgress(
      novelId: novelId,
      relativeOffset: relativeOffset ?? this.relativeOffset,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
