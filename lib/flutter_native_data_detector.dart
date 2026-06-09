/// Cross-platform text data detection for Flutter. Uses `NSDataDetector` on
/// iOS and ML Kit Entity Extraction on Android to detect phone numbers,
/// URLs, emails, dates, and addresses — returning structured results to Dart.
library;

export 'src/data_detector_controller.dart';
export 'src/data_detector_text_editing_controller.dart';
export 'src/detected_entities_controller.dart';
export 'src/detector.dart';
export 'src/entity_rich_text.dart';
export 'src/types.dart';
