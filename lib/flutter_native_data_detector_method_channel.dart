import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_native_data_detector_platform_interface.dart';

/// An implementation of [FlutterNativeDataDetectorPlatform] that uses method
/// channels.
class MethodChannelFlutterNativeDataDetector
    extends FlutterNativeDataDetectorPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_native_data_detector');

  @override
  Future<bool> prepareModel(String language) async {
    final ready = await methodChannel
        .invokeMethod<bool>('prepareModel', {'language': language});
    return ready ?? false;
  }

  @override
  Future<String> getModelStatus(String language) async {
    final status = await methodChannel
        .invokeMethod<String>('getModelStatus', {'language': language});
    return status ?? 'notDownloaded';
  }

  @override
  Future<List<Map<Object?, Object?>>> detect(
    String text,
    List<String> types,
    String language,
  ) async {
    final entities = await methodChannel.invokeListMethod<Object?>('detect', {
      'text': text,
      'types': types,
      'language': language,
    });
    return entities?.cast<Map<Object?, Object?>>() ?? const [];
  }
}
