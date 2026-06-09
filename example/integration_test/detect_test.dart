import 'package:flutter_native_data_detector/flutter_native_data_detector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const sample =
    'Call me at (555) 123-4567 or email john@example.com tomorrow at 9:30pm.';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('model reports ready (after prepare on Android)',
      (tester) async {
    expect(await NativeDataDetector.prepareModel(), isTrue);
    expect(await NativeDataDetector.isModelReady(), isTrue);
    expect(await NativeDataDetector.getModelStatus(), ModelStatus.ready);
  });

  testWidgets('detects phone, email and date with offsets and data',
      (tester) async {
    await NativeDataDetector.prepareModel();
    final entities = await NativeDataDetector.detect(sample);

    final phone =
        entities.singleWhere((e) => e.type == DetectionType.phoneNumber);
    expect(phone.text, contains('555'));
    expect(phone.data['phoneNumber'], isNotEmpty);

    final email = entities.singleWhere((e) => e.type == DetectionType.email);
    expect(email.text, 'john@example.com');
    expect(email.data['email'], 'john@example.com');

    final date = entities.singleWhere((e) => e.type == DetectionType.date);
    expect(date.data['date'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}T')));

    // start/end are Dart string indices: the slice must equal the match.
    for (final e in entities) {
      expect(sample.substring(e.start, e.end), e.text);
    }
  });

  testWidgets('types filter limits results', (tester) async {
    await NativeDataDetector.prepareModel();
    final entities = await NativeDataDetector.detect(
      sample,
      types: [DetectionType.email],
    );
    expect(entities, isNotEmpty);
    expect(entities.every((e) => e.type == DetectionType.email), isTrue);
  });
}
