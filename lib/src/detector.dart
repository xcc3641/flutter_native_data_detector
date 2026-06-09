import '../flutter_native_data_detector_platform_interface.dart';
import 'types.dart';

/// Cross-platform text data detection using native platform APIs:
/// `NSDataDetector` on iOS and ML Kit Entity Extraction on Android.
abstract final class NativeDataDetector {
  /// Pre-downloads the entity-detection model for [language] so that
  /// [detect] can run offline afterwards.
  ///
  /// On Android this downloads the ML Kit model for [language] (~5.6MB) if it
  /// is not already cached. On iOS this is a no-op that resolves immediately —
  /// `NSDataDetector` is built into the OS and requires no model.
  ///
  /// Returns `true` once the model is ready.
  static Future<bool> prepareModel({
    ModelLanguage language = ModelLanguage.en,
  }) {
    return FlutterNativeDataDetectorPlatform.instance
        .prepareModel(language.name);
  }

  /// Returns the download status of the model for [language].
  ///
  /// On Android this reflects whether the ML Kit model is cached on the
  /// device ([ModelStatus.ready] or [ModelStatus.notDownloaded]). On iOS this
  /// always resolves to [ModelStatus.ready].
  ///
  /// A pure status query never returns [ModelStatus.downloading] or
  /// [ModelStatus.error] — those states are only surfaced by
  /// `DataDetectorController` while it drives a download.
  static Future<ModelStatus> getModelStatus({
    ModelLanguage language = ModelLanguage.en,
  }) async {
    final status = await FlutterNativeDataDetectorPlatform.instance
        .getModelStatus(language.name);
    return ModelStatus.values.byName(status);
  }

  /// Convenience wrapper around [getModelStatus] that resolves `true` when
  /// the model for [language] is available and [detect] can run offline.
  static Future<bool> isModelReady({
    ModelLanguage language = ModelLanguage.en,
  }) async {
    return await getModelStatus(language: language) == ModelStatus.ready;
  }

  /// Detects entities (phone numbers, URLs, emails, addresses, dates) in
  /// [text] using native platform APIs.
  ///
  /// [types] selects which entity types to detect; defaults to all.
  /// [language] selects the Android ML Kit model; ignored on iOS.
  static Future<List<DetectedEntity>> detect(
    String text, {
    List<DetectionType>? types,
    ModelLanguage language = ModelLanguage.en,
  }) async {
    final typeNames =
        (types ?? DetectionType.values).map((t) => t.name).toList();
    final entities = await FlutterNativeDataDetectorPlatform.instance
        .detect(text, typeNames, language.name);
    return entities.map(DetectedEntity.fromMap).toList();
  }
}
