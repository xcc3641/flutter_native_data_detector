## 0.0.1

Initial release — a Flutter port of
[react-native-data-detector](https://github.com/pablogdcr/react-native-data-detector).

* `NativeDataDetector.detect` / `prepareModel` / `getModelStatus` / `isModelReady`
  backed by NSDataDetector (iOS) and ML Kit Entity Extraction (Android).
* Detects phone numbers, links, emails, addresses, and dates with structured
  `data` payloads and UTF-16 `start`/`end` offsets.
* `DataDetectorController` — imperative detection with model lifecycle tracking.
* `DetectedEntitiesController` — reactive, debounced as-you-type detection.
* `DataDetectorTextEditingController` — inline entity highlighting in editable
  text fields, with consumer-controlled appearance styling
  (`entityStyleBuilder` receives the appearance progress `t`).
* `EntityRichText` + `EntityPill` — built-in glowing-pill style for read-only
  surfaces; restylable per instance or replaceable via `entityBuilder`.
* 15 selectable ML Kit language models on Android.
