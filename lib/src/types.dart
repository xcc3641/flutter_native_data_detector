/// The type of entity detected in the text.
enum DetectionType { phoneNumber, link, email, address, date }

/// A language model supported by ML Kit Entity Extraction on Android,
/// expressed as an ISO 639-1 code. Selects which on-device model is used for
/// detection.
///
/// Ignored on iOS — `NSDataDetector` is language-agnostic and needs no model.
enum ModelLanguage {
  ar, // Arabic
  nl, // Dutch
  en, // English
  fr, // French
  de, // German
  it, // Italian
  ja, // Japanese
  ko, // Korean
  pl, // Polish
  pt, // Portuguese
  ru, // Russian
  es, // Spanish
  th, // Thai
  tr, // Turkish
  zh, // Chinese
}

/// The download state of a detection model.
///
/// - [notDownloaded] — the model is not available on the device yet
///   (Android only).
/// - [downloading] — a download is currently in progress. Only reported by
///   [DataDetectorController] while it drives a download; native status
///   queries never return this.
/// - [ready] — the model is available and `detect()` can run offline. iOS
///   always reports `ready` since `NSDataDetector` requires no model.
/// - [error] — the last preparation attempt failed. Only reported by the
///   controller.
enum ModelStatus { notDownloaded, downloading, ready, error }

/// A single detected entity within the text.
class DetectedEntity {
  const DetectedEntity({
    required this.type,
    required this.text,
    required this.start,
    required this.end,
    this.data = const {},
  });

  /// Decodes an entity from the platform channel wire format.
  factory DetectedEntity.fromMap(Map<Object?, Object?> map) {
    return DetectedEntity(
      type: DetectionType.values.byName(map['type']! as String),
      text: map['text']! as String,
      start: (map['start']! as num).toInt(),
      end: (map['end']! as num).toInt(),
      data:
          (map['data'] as Map<Object?, Object?>?)?.cast<String, String>() ??
          const {},
    );
  }

  /// The type of detected entity.
  final DetectionType type;

  /// The matched text substring.
  final String text;

  /// Start index of the match in the original string (UTF-16 code units,
  /// which is what Dart string indices are).
  final int start;

  /// End index (exclusive) of the match in the original string.
  final int end;

  /// Additional structured data depending on [type]:
  ///
  /// | type          | fields                                              |
  /// |---------------|-----------------------------------------------------|
  /// | `phoneNumber` | `phoneNumber`                                       |
  /// | `link`        | `url`                                               |
  /// | `email`       | `email`                                             |
  /// | `address`     | `street`,`city`,`state`,`zip`,`country` (iOS) / `address` (Android) |
  /// | `date`        | `date` — ISO 8601 string                            |
  final Map<String, String> data;

  @override
  bool operator ==(Object other) =>
      other is DetectedEntity &&
      other.type == type &&
      other.text == text &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(type, text, start, end);

  @override
  String toString() =>
      'DetectedEntity(${type.name}, "$text", $start..$end, $data)';
}

/// Helpers over a detection result.
extension DetectedEntityList on List<DetectedEntity> {
  /// The entities whose ranges are safe to apply to [text].
  ///
  /// A detection result can lag the text it was computed from (debounce), so
  /// a range is only trusted when it still slices to the matched text.
  /// Overlapping ranges (possible across detector engines) keep the first.
  /// The result is sorted by [DetectedEntity.start].
  List<DetectedEntity> validIn(String text) {
    final sorted = [...this]..sort((a, b) => a.start.compareTo(b.start));
    final valid = <DetectedEntity>[];
    var lastEnd = 0;
    for (final e in sorted) {
      if (e.start < lastEnd || e.end > text.length) continue;
      if (text.substring(e.start, e.end) != e.text) continue;
      valid.add(e);
      lastEnd = e.end;
    }
    return valid;
  }
}
