import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_data_detector/flutter_native_data_detector.dart';
import 'package:flutter_native_data_detector/flutter_native_data_detector_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakePlatform extends FlutterNativeDataDetectorPlatform
    with MockPlatformInterfaceMixin {
  FakePlatform({
    this.initialStatus = 'notDownloaded',
    this.prepareError,
    this.detectError,
  });

  String initialStatus;
  Object? prepareError;
  Object? detectError;

  final preparedLanguages = <String>[];
  final detectCalls = <(String, List<String>, String)>[];
  List<Map<Object?, Object?>> detectResult = const [];

  /// Completes in-flight detects when set; lets tests control async order.
  Future<void> Function()? detectGate;

  @override
  Future<bool> prepareModel(String language) async {
    if (prepareError case final e?) throw e;
    preparedLanguages.add(language);
    initialStatus = 'ready';
    return true;
  }

  @override
  Future<String> getModelStatus(String language) async => initialStatus;

  @override
  Future<List<Map<Object?, Object?>>> detect(
    String text,
    List<String> types,
    String language,
  ) async {
    detectCalls.add((text, types, language));
    await detectGate?.call();
    if (detectError case final e?) throw e;
    return detectResult;
  }
}

void main() {
  late FakePlatform fake;

  setUp(() {
    fake = FakePlatform();
    FlutterNativeDataDetectorPlatform.instance = fake;
  });

  group('NativeDataDetector', () {
    test('detect defaults to all types and English', () async {
      fake.detectResult = [
        {
          'type': 'phoneNumber',
          'text': '555-1234',
          'start': 11,
          'end': 19,
          'data': {'phoneNumber': '555-1234'},
        },
      ];

      final entities = await NativeDataDetector.detect('Call me at 555-1234');

      final call = fake.detectCalls.single;
      expect(call.$1, 'Call me at 555-1234');
      expect(call.$2, ['phoneNumber', 'link', 'email', 'address', 'date']);
      expect(call.$3, 'en');
      final entity = entities.single;
      expect(entity.type, DetectionType.phoneNumber);
      expect(entity.text, '555-1234');
      expect(entity.start, 11);
      expect(entity.end, 19);
      expect(entity.data, {'phoneNumber': '555-1234'});
    });

    test('detect forwards selected types and language', () async {
      await NativeDataDetector.detect(
        'x',
        types: [DetectionType.email],
        language: ModelLanguage.fr,
      );
      final call = fake.detectCalls.single;
      expect(call.$1, 'x');
      expect(call.$2, ['email']);
      expect(call.$3, 'fr');
    });

    test('entity with missing data decodes to empty map', () async {
      fake.detectResult = [
        {'type': 'link', 'text': 'https://x.co', 'start': 0, 'end': 12},
      ];
      final entities = await NativeDataDetector.detect('https://x.co');
      expect(entities.single.data, isEmpty);
    });

    test('getModelStatus / isModelReady map wire strings', () async {
      expect(
        await NativeDataDetector.getModelStatus(),
        ModelStatus.notDownloaded,
      );
      expect(await NativeDataDetector.isModelReady(), isFalse);

      fake.initialStatus = 'ready';
      expect(await NativeDataDetector.getModelStatus(), ModelStatus.ready);
      expect(await NativeDataDetector.isModelReady(), isTrue);
    });

    test('prepareModel passes language', () async {
      await NativeDataDetector.prepareModel(language: ModelLanguage.zh);
      expect(fake.preparedLanguages, ['zh']);
    });
  });

  group('DataDetectorController', () {
    test('autoPrepare downloads model and settles on ready', () async {
      final controller = DataDetectorController();
      final seen = <ModelStatus>[];
      controller.addListener(() => seen.add(controller.status));

      await pumpEventQueue();

      expect(seen, [ModelStatus.downloading, ModelStatus.ready]);
      expect(controller.isReady, isTrue);
      expect(fake.preparedLanguages, ['en']);
      controller.dispose();
    });

    test('already-ready model skips download', () async {
      fake.initialStatus = 'ready';
      final controller = DataDetectorController();
      await pumpEventQueue();

      expect(controller.status, ModelStatus.ready);
      expect(fake.preparedLanguages, isEmpty);
      controller.dispose();
    });

    test('autoPrepare=false leaves model notDownloaded', () async {
      final controller = DataDetectorController(autoPrepare: false);
      await pumpEventQueue();

      expect(controller.status, ModelStatus.notDownloaded);
      expect(fake.preparedLanguages, isEmpty);

      await controller.prepare();
      expect(controller.status, ModelStatus.ready);
      controller.dispose();
    });

    test('prepare failure surfaces error status', () async {
      fake.prepareError = StateError('offline');
      final controller = DataDetectorController();
      await pumpEventQueue();

      expect(controller.status, ModelStatus.error);
      expect(controller.error, isA<StateError>());
      controller.dispose();
    });

    test('changing language re-prepares', () async {
      final controller = DataDetectorController();
      await pumpEventQueue();
      expect(fake.preparedLanguages, ['en']);

      fake.initialStatus = 'notDownloaded';
      controller.language = ModelLanguage.ja;
      await pumpEventQueue();

      expect(fake.preparedLanguages, ['en', 'ja']);
      expect(controller.isReady, isTrue);
      controller.dispose();
    });

    test('detect uses configured language', () async {
      final controller = DataDetectorController(language: ModelLanguage.ko);
      await pumpEventQueue();
      await controller.detect('hi', types: [DetectionType.date]);

      final call = fake.detectCalls.single;
      expect(call.$1, 'hi');
      expect(call.$2, ['date']);
      expect(call.$3, 'ko');
      controller.dispose();
    });

    test('dispose during prepare does not notify after dispose', () async {
      final controller = DataDetectorController();
      controller.dispose();
      // _checkModel resolving after dispose must be a no-op (no thrown
      // "used after dispose" from notifyListeners).
      await pumpEventQueue();
    });
  });

  group('DetectedEntitiesController', () {
    const debounce = Duration(milliseconds: 50);

    test('detects initial text once model is ready', () async {
      fake.detectResult = [
        {'type': 'email', 'text': 'a@b.co', 'start': 0, 'end': 6},
      ];
      final controller = DetectedEntitiesController(
        text: 'a@b.co',
        debounce: debounce,
      );
      await pumpEventQueue();

      expect(controller.isReady, isTrue);
      expect(controller.entities.single.text, 'a@b.co');
      controller.dispose();
    });

    test('debounces text changes — only last value is detected', () {
      fakeAsync((async) {
        fake.initialStatus = 'ready';
        final controller = DetectedEntitiesController(debounce: debounce);
        async.flushMicrotasks();
        fake.detectCalls.clear();

        controller.text = 'h';
        async.elapse(const Duration(milliseconds: 20));
        controller.text = 'he';
        async.elapse(const Duration(milliseconds: 20));
        controller.text = 'hello';
        async.elapse(const Duration(milliseconds: 60));
        async.flushMicrotasks();

        expect(fake.detectCalls.single.$1, 'hello');
        controller.dispose();
      });
    });

    test('clearing text empties entities without a native call', () {
      fakeAsync((async) {
        fake.initialStatus = 'ready';
        fake.detectResult = [
          {'type': 'email', 'text': 'a@b.co', 'start': 0, 'end': 6},
        ];
        final controller = DetectedEntitiesController(
          text: 'a@b.co',
          debounce: debounce,
        );
        async.flushMicrotasks();
        expect(controller.entities, hasLength(1));
        fake.detectCalls.clear();

        controller.text = '';
        async.elapse(const Duration(milliseconds: 60));
        async.flushMicrotasks();

        expect(controller.entities, isEmpty);
        expect(controller.isDetecting, isFalse);
        expect(fake.detectCalls, isEmpty);
        controller.dispose();
      });
    });

    test('enabled=false pauses detection and keeps last result', () {
      fakeAsync((async) {
        fake.initialStatus = 'ready';
        fake.detectResult = [
          {'type': 'email', 'text': 'a@b.co', 'start': 0, 'end': 6},
        ];
        final controller = DetectedEntitiesController(
          text: 'a@b.co',
          debounce: debounce,
        );
        async.flushMicrotasks();
        fake.detectCalls.clear();

        controller.enabled = false;
        controller.text = 'changed';
        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        expect(fake.detectCalls, isEmpty);
        expect(controller.entities, hasLength(1)); // last result kept

        controller.enabled = true;
        async.flushMicrotasks();
        expect(fake.detectCalls.single.$1, 'changed');
        controller.dispose();
      });
    });

    test('detection error is exposed and cleared on next success', () {
      fakeAsync((async) {
        fake.initialStatus = 'ready';
        fake.detectError = StateError('boom');
        final controller = DetectedEntitiesController(
          text: 'x',
          debounce: debounce,
        );
        async.flushMicrotasks();

        expect(controller.error, isA<StateError>());
        expect(controller.isDetecting, isFalse);

        fake.detectError = null;
        controller.text = 'y';
        async.elapse(const Duration(milliseconds: 60));
        async.flushMicrotasks();

        expect(controller.error, isNull);
        controller.dispose();
      });
    });

    test('changing types re-runs detection', () {
      fakeAsync((async) {
        fake.initialStatus = 'ready';
        final controller = DetectedEntitiesController(
          text: 'x',
          debounce: debounce,
        );
        async.flushMicrotasks();
        fake.detectCalls.clear();

        controller.types = [DetectionType.phoneNumber];
        async.flushMicrotasks();

        expect(fake.detectCalls.single.$2, ['phoneNumber']);
        controller.dispose();
      });
    });
  });
  group('DataDetectorTextEditingController', () {
    testWidgets('styles detected entity ranges inline', (tester) async {
      fake.initialStatus = 'ready';
      fake.detectResult = [
        {'type': 'email', 'text': 'a@b.co', 'start': 5, 'end': 11},
      ];
      final controller = DataDetectorTextEditingController(
        text: 'mail a@b.co now',
        debounce: Duration.zero,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TextField(controller: controller)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(controller.entities, hasLength(1));

      final span = controller.buildTextSpan(
        context: tester.element(find.byType(TextField)),
        style: const TextStyle(),
        withComposing: false,
      );
      final children = span.children!;
      expect(children, hasLength(3));
      expect((children[0] as TextSpan).text, 'mail ');
      expect((children[1] as TextSpan).text, 'a@b.co');
      expect(
        (children[1] as TextSpan).style?.color,
        defaultEntityColors[DetectionType.email],
      );
      expect((children[2] as TextSpan).text, ' now');

      controller.dispose();
    });

    testWidgets('stale entity ranges are not styled after text changes', (
      tester,
    ) async {
      fake.initialStatus = 'ready';
      fake.detectResult = [
        {'type': 'email', 'text': 'a@b.co', 'start': 5, 'end': 11},
      ];
      final controller = DataDetectorTextEditingController(
        text: 'mail a@b.co now',
        debounce: Duration.zero,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TextField(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.entities, hasLength(1));

      // Edit the text so the entity's range no longer slices to its match;
      // before re-detection lands, the old range must not be styled.
      controller.text = 'mail b.co now';
      final span = controller.buildTextSpan(
        context: tester.element(find.byType(TextField)),
        style: const TextStyle(),
        withComposing: false,
      );
      expect(span.toPlainText(), 'mail b.co now');
      expect(
        span.children?.whereType<TextSpan>().where(
          (s) => s.style?.color == defaultEntityColors[DetectionType.email],
        ),
        anyOf(isNull, isEmpty),
      );

      controller.dispose();
      await tester.pumpAndSettle();
    });

    testWidgets(
      'highlight fades in: base style at t=0, full style when settled',
      (tester) async {
        fake.initialStatus = 'ready';
        fake.detectResult = [
          {'type': 'email', 'text': 'a@b.co', 'start': 5, 'end': 11},
        ];
        const baseColor = Color(0xFF112233);
        final controller = DataDetectorTextEditingController(
          text: 'mail a@b.co now',
          debounce: Duration.zero,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: TextField(controller: controller)),
          ),
        );
        // One zero-duration pump: detection has landed, no animation time yet.
        await tester.pump();
        expect(controller.entities, hasLength(1));

        TextSpan entitySpan() =>
            controller
                    .buildTextSpan(
                      context: tester.element(find.byType(TextField)),
                      style: const TextStyle(color: baseColor),
                      withComposing: false,
                    )
                    .children![1]
                as TextSpan;

        expect(entitySpan().style?.color, baseColor); // t == 0 → still base

        // Push the fake clock past highlightDuration; the Timer-driven ticker
        // fires during the advance and settles at t == 1.
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          entitySpan().style?.color,
          defaultEntityColors[DetectionType.email],
        ); // t == 1 → full

        controller.dispose();
      },
    );

    testWidgets('highlightDuration zero disables the transition', (
      tester,
    ) async {
      fake.initialStatus = 'ready';
      fake.detectResult = [
        {'type': 'email', 'text': 'a@b.co', 'start': 5, 'end': 11},
      ];
      final controller = DataDetectorTextEditingController(
        text: 'mail a@b.co now',
        debounce: Duration.zero,
        highlightDuration: Duration.zero,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TextField(controller: controller)),
        ),
      );
      await tester.pump();

      final span = controller.buildTextSpan(
        context: tester.element(find.byType(TextField)),
        style: const TextStyle(color: Color(0xFF112233)),
        withComposing: false,
      );
      expect(
        (span.children![1] as TextSpan).style?.color,
        defaultEntityColors[DetectionType.email],
      );

      controller.dispose();
    });

    testWidgets('entityStyleBuilder receives the appearance progress t', (
      tester,
    ) async {
      fake.initialStatus = 'ready';
      fake.detectResult = [
        {'type': 'email', 'text': 'a@b.co', 'start': 5, 'end': 11},
      ];
      final seenT = <double>[];
      final controller = DataDetectorTextEditingController(
        text: 'mail a@b.co now',
        debounce: Duration.zero,
        entityStyleBuilder: (entity, base, t) {
          seenT.add(t);
          return base.copyWith(decoration: TextDecoration.underline);
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TextField(controller: controller)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final span = controller.buildTextSpan(
        context: tester.element(find.byType(TextField)),
        style: const TextStyle(),
        withComposing: false,
      );
      expect(
        (span.children![1] as TextSpan).style?.decoration,
        TextDecoration.underline,
      );
      expect(seenT.first, lessThan(1)); // animated in…
      expect(seenT.last, 1); // …up to fully appeared
      expect(seenT.every((t) => t >= 0 && t <= 1), isTrue);

      controller.dispose();
    });
  });

  group('DetectedEntityList.validIn', () {
    const email = DetectedEntity(
      type: DetectionType.email,
      text: 'a@b.co',
      start: 5,
      end: 11,
    );

    test('keeps ranges that slice to the matched text, sorted', () {
      const phone = DetectedEntity(
        type: DetectionType.phoneNumber,
        text: '555',
        start: 0,
        end: 3,
      );
      expect([email, phone].validIn('555m a@b.co'), [phone, email]);
    });

    test('drops out-of-bounds, mismatched and overlapping ranges', () {
      expect([email].validIn('a@b.co'), isEmpty); // out of bounds
      expect([email].validIn('mail x@y.zz now'), isEmpty); // mismatch
      const overlap = DetectedEntity(
        type: DetectionType.link,
        text: 'b.co',
        start: 7,
        end: 11,
      );
      expect([email, overlap].validIn('mail a@b.co now'), [email]);
    });
  });

  group('EntityRichText', () {
    const entity = DetectedEntity(
      type: DetectionType.email,
      text: 'a@b.co',
      start: 5,
      end: 11,
    );

    testWidgets('renders the built-in pill for valid entities', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EntityRichText(text: 'mail a@b.co now', entities: [entity]),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(EntityPill), findsOneWidget);
      expect(find.text('a@b.co'), findsOneWidget);
      expect(find.text('✉️'), findsOneWidget);
    });

    testWidgets('skips stale ranges and renders plain text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EntityRichText(text: 'mail b.co now', entities: [entity]),
          ),
        ),
      );
      expect(find.byType(EntityPill), findsNothing);
    });

    testWidgets('entityBuilder replaces the built-in pill', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntityRichText(
              text: 'mail a@b.co now',
              entities: const [entity],
              entityBuilder: (context, e) =>
                  Text('[${e.type.name}]', key: const Key('custom')),
            ),
          ),
        ),
      );
      expect(find.byType(EntityPill), findsNothing);
      expect(find.byKey(const Key('custom')), findsOneWidget);
    });

    testWidgets('EntityPill appearDuration zero renders statically', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EntityPill(entity: entity, appearDuration: Duration.zero),
          ),
        ),
      );
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
      expect(find.text('a@b.co'), findsOneWidget);
    });
  });
}

// Small wrapper so tests read naturally.
void fakeAsync(void Function(FakeAsync async) body) {
  FakeAsync().run(body);
}
