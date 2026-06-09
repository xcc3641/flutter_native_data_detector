# flutter_native_data_detector

[![pub package](https://img.shields.io/pub/v/flutter_native_data_detector.svg)](https://pub.dev/packages/flutter_native_data_detector)
[![pub points](https://img.shields.io/pub/points/flutter_native_data_detector)](https://pub.dev/packages/flutter_native_data_detector/score)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-android%20%7C%20ios-blue.svg)](https://pub.dev/packages/flutter_native_data_detector)

English | [简体中文](README.zh-CN.md)

Cross-platform text data detection for Flutter. Uses **NSDataDetector** on iOS and **ML Kit Entity Extraction** on Android to detect phone numbers, URLs, emails, dates, and addresses — returning structured results to Dart.

A Flutter port of [react-native-data-detector](https://github.com/pablogdcr/react-native-data-detector).

| Live detection demo | Entity pills |
| :---: | :---: |
| <img src="https://raw.githubusercontent.com/xcc3641/flutter_native_data_detector/main/images/demo.gif" width="320" alt="Typing live detection demo with animated entity pills" /> | <img src="https://raw.githubusercontent.com/xcc3641/flutter_native_data_detector/main/images/screenshot.png" width="320" alt="All five entity types rendered as glowing pills" /> |

It is built on top of:

- **iOS**: `NSDataDetector` (built into the OS, no model download)
- **Android**: Google ML Kit Entity Extraction (~5.6MB on-device model per language)

## Features

- **Phone numbers** — Detect and extract phone numbers
- **URLs** — Detect web links
- **Emails** — Detect email addresses
- **Addresses** — Detect street addresses with parsed components (iOS)
- **Dates** — Detect dates and times with ISO 8601 output

- **Native accuracy** — Uses native APIs instead of regex
- **Controllers** — `DataDetectorController` (imperative) and `DetectedEntitiesController` (reactive, as-you-type); both track model readiness and auto-download on Android
- **Inline highlighting** — `DataDetectorTextEditingController` lights up entities in a `TextField` as the user types
- **Entity pills** — `EntityRichText` + `EntityPill` render detected entities as glowing inline pills for read-only surfaces; fully restylable or replaceable
- **Multiple languages** — Choose from 15 ML Kit language models on Android

## Installation

```bash
flutter pub add flutter_native_data_detector
```

### Android

The ML Kit entity extraction model (~5.6MB per language) is downloaded on the user's device at runtime. You can control when this happens using `NativeDataDetector.prepareModel()` or `DataDetectorController` (which downloads automatically on construction) — for example, to ensure `detect()` works offline later. If you don't trigger it explicitly, the model is downloaded automatically on the first `detect()` call.

Requires `minSdkVersion 26` (ML Kit Entity Extraction).

## Usage

### Functions

```dart
import 'package:flutter_native_data_detector/flutter_native_data_detector.dart';

// Pre-download the ML Kit model at app startup (Android only, no-op on iOS)
await NativeDataDetector.prepareModel();

// Detect all entity types
final entities = await NativeDataDetector.detect(
  'Call me at 555-1234 or email john@example.com',
);
// [
//   DetectedEntity(phoneNumber, "555-1234", 11..19, {phoneNumber: 555-1234}),
//   DetectedEntity(email, "john@example.com", 29..45, {email: john@example.com}),
// ]

// Detect only specific types
final phones = await NativeDataDetector.detect(
  'Call 555-1234 or visit https://example.com',
  types: [DetectionType.phoneNumber],
);

// Use a specific language model (Android only, ignored on iOS)
final fr = await NativeDataDetector.detect(
  'Appelez-moi au 01 23 45 67 89',
  language: ModelLanguage.fr,
);
```

### Controllers

Two `ChangeNotifier` controllers for two situations:

- **`DataDetectorController`** — *imperative*. Tracks model readiness and hands you a
  `detect` method you call yourself (e.g. once per chat message).
- **`DetectedEntitiesController`** — *reactive*. Feed it a (changing) string via `text` and it
  exposes the detected entities, debounced and recomputed as the text changes — ideal for
  as-you-type input.

Both download the model automatically on Android and are no-ops on iOS (always ready).

```dart
final detector = DataDetectorController();

// status: ModelStatus.notDownloaded | downloading | ready | error
if (detector.isReady) {
  final entities = await detector.detect(text, types: [DetectionType.email]);
}
```

```dart
final live = DetectedEntitiesController(debounce: Duration(milliseconds: 250));

// From a TextField:
TextField(onChanged: (text) => live.text = text);

// Rebuild on changes:
ListenableBuilder(
  listenable: live,
  builder: (context, _) => Text(
    '${live.entities.length} detected${live.isDetecting ? '…' : ''}',
  ),
);
```

### Inline highlighting

`DataDetectorTextEditingController` is a `TextEditingController` that detects
entities as the user types and highlights them inline — each entity type in
its own color with a soft glow — while the field stays fully editable:

```dart
final controller = DataDetectorTextEditingController();

TextField(controller: controller);

// Structured results live on the embedded reactive controller:
controller.detection.addListener(() {
  print(controller.entities);
});
```

Newly detected entities fade in over `highlightDuration` (default 350ms).
The package only drives the **appearance progress** `t` (linear `0.0 → 1.0`);
how an entity looks at any `t` is entirely yours via `entityStyleBuilder` —
bring your own curve, colors, or ignore `t` for a static style:

```dart
DataDetectorTextEditingController(
  highlightDuration: const Duration(milliseconds: 500),
  entityStyleBuilder: (entity, base, t) => base.copyWith(
    color: Color.lerp(base.color, Colors.amber, Curves.easeOutCubic.transform(t)),
    decoration: TextDecoration.underline,
  ),
);
```

Escape hatches, from light to total control:

1. `highlightDuration: Duration.zero` — no transition, `t` is always `1.0`.
2. `entityStyleBuilder` — full control of the inline style at any progress.
3. Subclass and override `buildTextSpan`, building from the public
   `validEntities` (stale-range-guarded, sorted) — replace the rendering
   entirely.

### Entity pills (read-only display)

For display surfaces — message bubbles, previews — `EntityRichText` renders
text with each detected entity drawn inline, by default as the built-in
`EntityPill`: a glowing rounded pill with the entity-type icon, fading in
when the entity first appears. (`WidgetSpan` pills can't live inside an
editable `TextField`, which is why the editable surface uses style-only
highlighting instead.)

```dart
EntityRichText(
  text: message,
  entities: entities, // from any detect() / controller
  style: const TextStyle(fontSize: 17, height: 2.0),
)
```

Use it as-is, restyle the pill, or replace it entirely:

```dart
// Tweak the built-in pill…
EntityRichText(
  text: message,
  entities: entities,
  entityBuilder: (context, entity) => EntityPill(
    entity: entity,
    color: Colors.teal,
    icon: '', // hide the icon
    appearDuration: Duration.zero,
  ),
);

// …or bring your own widget.
EntityRichText(
  text: message,
  entities: entities,
  entityBuilder: (context, entity) => Chip(label: Text(entity.text)),
);
```

Entity ranges are validated against `text` before rendering (the
`entities.validIn(text)` extension, also public), so results that lag the
text never mis-render.

## API

### `NativeDataDetector.prepareModel({language})`

Pre-downloads the entity-detection model so `detect()` can run offline afterwards. On iOS, this is a no-op that resolves immediately — `NSDataDetector` is built into the OS and requires no model download.

Returns `Future<bool>` — `true` when the model is ready.

| Platform | Behavior |
|----------|----------|
| **iOS** | No-op, resolves `true` immediately |
| **Android** | Downloads the ML Kit model (~5.6MB) for the language if not already cached. Requires internet on first call. |

### `NativeDataDetector.getModelStatus({language})`

Returns the download status of the model for the given language: `ModelStatus.ready` or `ModelStatus.notDownloaded`. On iOS always resolves `ready`. (A pure query never returns `downloading` or `error` — those are only surfaced by `DataDetectorController`.)

### `NativeDataDetector.isModelReady({language})`

Convenience wrapper around `getModelStatus`. Resolves `true` when the model for the given language is available.

### `NativeDataDetector.detect(text, {types, language})`

Detects entities in the given text using native platform APIs.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `text` | `String` | — | The text to analyze |
| `types` | `List<DetectionType>?` | All types | Which entity types to detect |
| `language` | `ModelLanguage` | `en` | Which language model to use (Android only). Ignored on iOS. |

Returns `Future<List<DetectedEntity>>`.

### `DataDetectorController({language, autoPrepare})`

`ChangeNotifier` that tracks model availability and, on Android, downloads the language model automatically. On iOS the model is always available, so `status` settles on `ready`.

| Member | Type | Description |
|--------|------|-------------|
| `detect(text, {types})` | `Future<List<DetectedEntity>>` | Detect entities using the configured language. |
| `prepare()` | `Future<void>` | Manually (re)download the configured language model. |
| `status` | `ModelStatus` | `notDownloaded` / `downloading` / `ready` / `error`. |
| `isReady` | `bool` | `true` when `status == ModelStatus.ready`. |
| `error` | `Object?` | The last preparation error, or `null`. |
| `language` | `ModelLanguage` | Mutable; changing it re-checks/prepares the new model. |

### `DetectedEntitiesController({text, debounce, types, language, enabled, autoPrepare})`

Reactive `ChangeNotifier`: set `text` as it changes and read back the detected entities, debounced and cancellation-safe (the latest text wins). Manages model readiness internally.

| Member | Type | Description |
|--------|------|-------------|
| `text` | `String` | Mutable; setting it (re)starts the debounce timer. |
| `entities` | `List<DetectedEntity>` | Entities detected in the debounced `text`. |
| `isDetecting` | `bool` | `true` while a detection for the latest text is in flight. |
| `status` | `ModelStatus` | Current model download state. |
| `error` | `Object?` | The last detection or model error, or `null`. |
| `enabled` | `bool` | Mutable; when `false`, detection pauses and the last result is kept. |
| `debounce` | `Duration` | Debounce applied to `text` (default 300ms). |
| `types` | `List<DetectionType>?` | Mutable; which entity types to detect (`null` = all). |
| `language` | `ModelLanguage` | Mutable; selects the Android model and re-runs detection. |

### `DataDetectorTextEditingController({text, debounce, types, language, enabled, autoPrepare, highlightDuration, entityStyleBuilder})`

A `TextEditingController` that highlights detected entities inline while staying fully editable (only styles change, never characters, so cursor and selection are unaffected). Detection results that lag the text by the debounce interval are range-checked before styling, so edits never mis-highlight.

| Member | Type | Description |
|--------|------|-------------|
| `detection` | `DetectedEntitiesController` | The embedded reactive detection state. |
| `entities` | `List<DetectedEntity>` | Entities currently detected in the text. |
| `validEntities` | `List<DetectedEntity>` | Stale-range-guarded, sorted entities — the safe basis for custom `buildTextSpan` overrides. |
| `highlightDuration` | `Duration` | Fade-in length for newly detected entities (default 350ms; `Duration.zero` disables). |
| `entityStyleBuilder` | `TextStyle Function(DetectedEntity, TextStyle base, double t)?` | Full control of the inline style at appearance progress `t` (linear 0→1). |

### `DetectedEntity`

| Property | Type | Description |
|----------|------|-------------|
| `type` | `DetectionType` | The type of detected entity |
| `text` | `String` | The matched text substring |
| `start` | `int` | Start index in the original string (UTF-16 code units, i.e. Dart string indices) |
| `end` | `int` | End index (exclusive) in the original string |
| `data` | `Map<String, String>` | Additional structured data (see below) |

### Entity Data by Type

| Type | Data fields |
|------|-------------|
| `phoneNumber` | `{ phoneNumber }` |
| `link` | `{ url }` |
| `email` | `{ email }` |
| `address` | `{ street, city, state, zip, country }` (iOS) / `{ address }` (Android) |
| `date` | `{ date }` ISO 8601 string |

## Supported Languages

The `language` option (enum `ModelLanguage`) selects which **Android** ML Kit model is used. It is a no-op on iOS, where `NSDataDetector` is language-agnostic. Each language is a separate ~5.6MB on-device model, downloaded on demand.

| Code | Language | Code | Language   | Code | Language |
| ---- | -------- | ---- | ---------- | ---- | -------- |
| `ar` | Arabic   | `it` | Italian    | `ru` | Russian  |
| `nl` | Dutch    | `ja` | Japanese   | `es` | Spanish  |
| `en` | English  | `ko` | Korean     | `th` | Thai     |
| `fr` | French   | `pl` | Polish     | `tr` | Turkish  |
| `de` | German   | `pt` | Portuguese | `zh` | Chinese  |

## Platform Differences

| Feature | iOS | Android |
|---------|-----|---------|
| Engine | NSDataDetector | ML Kit Entity Extraction |
| Offline | Always | After `prepareModel()` or first `detect()` call |
| Model download | Not needed | ~5.6MB per language, on-device at runtime |
| Language selection | Language-agnostic (option ignored) | 15 selectable language models |
| Address parsing | Structured components | Raw string |
| Date output | ISO 8601 | ISO 8601 |

## Requirements

- iOS 13.0+
- Android API 26+ (minSdk) — required by ML Kit Entity Extraction

## License

MIT
