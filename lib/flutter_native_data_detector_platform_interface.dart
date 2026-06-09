import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_native_data_detector_method_channel.dart';

/// The interface that implementations of flutter_native_data_detector must
/// implement.
///
/// Methods speak the raw wire format (`String` language codes, `List<String>`
/// type names, `List<Map>` entities); enum conversion and entity parsing live
/// in the public `NativeDataDetector` API so they exist in exactly one place.
abstract class FlutterNativeDataDetectorPlatform extends PlatformInterface {
  FlutterNativeDataDetectorPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterNativeDataDetectorPlatform _instance =
      MethodChannelFlutterNativeDataDetector();

  /// The default instance of [FlutterNativeDataDetectorPlatform] to use.
  static FlutterNativeDataDetectorPlatform get instance => _instance;

  static set instance(FlutterNativeDataDetectorPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Downloads the detection model for [language] if needed.
  /// Resolves `true` once the model is ready.
  Future<bool> prepareModel(String language) {
    throw UnimplementedError('prepareModel() has not been implemented.');
  }

  /// Returns `'ready'` or `'notDownloaded'` for the model of [language].
  Future<String> getModelStatus(String language) {
    throw UnimplementedError('getModelStatus() has not been implemented.');
  }

  /// Detects entities of [types] in [text] using the model for [language].
  Future<List<Map<Object?, Object?>>> detect(
    String text,
    List<String> types,
    String language,
  ) {
    throw UnimplementedError('detect() has not been implemented.');
  }
}
