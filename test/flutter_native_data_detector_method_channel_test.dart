import 'package:flutter/services.dart';
import 'package:flutter_native_data_detector/flutter_native_data_detector_method_channel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelFlutterNativeDataDetector();

  MethodCall? lastCall;

  void mockHandler(Object? Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platform.methodChannel, (call) async {
      lastCall = call;
      return handler(call);
    });
  }

  tearDown(() {
    lastCall = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platform.methodChannel, null);
  });

  test('prepareModel passes language and returns result', () async {
    mockHandler((_) => true);
    expect(await platform.prepareModel('fr'), isTrue);
    expect(lastCall, isMethodCall('prepareModel', arguments: {'language': 'fr'}));
  });

  test('getModelStatus passes language and returns status', () async {
    mockHandler((_) => 'notDownloaded');
    expect(await platform.getModelStatus('de'), 'notDownloaded');
    expect(
      lastCall,
      isMethodCall('getModelStatus', arguments: {'language': 'de'}),
    );
  });

  test('detect passes text/types/language and returns raw maps', () async {
    mockHandler((_) => [
          {
            'type': 'email',
            'text': 'a@b.co',
            'start': 0,
            'end': 6,
            'data': {'email': 'a@b.co'},
          },
        ]);

    final entities = await platform.detect('a@b.co', ['email'], 'en');

    expect(
      lastCall,
      isMethodCall('detect', arguments: {
        'text': 'a@b.co',
        'types': ['email'],
        'language': 'en',
      }),
    );
    expect(entities, hasLength(1));
    expect(entities.first['type'], 'email');
  });
}
