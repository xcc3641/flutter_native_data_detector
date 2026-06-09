# flutter_native_data_detector

[![pub package](https://img.shields.io/pub/v/flutter_native_data_detector.svg)](https://pub.dev/packages/flutter_native_data_detector)
[![pub points](https://img.shields.io/pub/points/flutter_native_data_detector)](https://pub.dev/packages/flutter_native_data_detector/score)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-android%20%7C%20ios-blue.svg)](https://pub.dev/packages/flutter_native_data_detector)

[English](README.md) | 简体中文

跨平台的 Flutter 文本数据检测插件。iOS 端使用 **NSDataDetector**，Android 端使用 **ML Kit Entity Extraction**，检测文本中的电话号码、URL、邮箱、日期和地址，并以结构化结果返回 Dart 层。

[react-native-data-detector](https://github.com/pablogdcr/react-native-data-detector) 的 Flutter 移植版。

| 实时检测演示 | 实体胶囊 |
| :---: | :---: |
| <img src="https://raw.githubusercontent.com/xcc3641/flutter_native_data_detector/main/images/demo.gif" width="320" alt="Typing live detection demo with animated entity pills" /> | <img src="https://raw.githubusercontent.com/xcc3641/flutter_native_data_detector/main/images/screenshot.png" width="320" alt="All five entity types rendered as glowing pills" /> |

底层依赖：

- **iOS**：`NSDataDetector`（系统内置，无需下载模型）
- **Android**：Google ML Kit Entity Extraction（每种语言约 5.6MB 的端侧模型）

## 功能特性

- **电话号码** — 检测并提取电话号码
- **URL** — 检测网页链接
- **邮箱** — 检测电子邮件地址
- **地址** — 检测街道地址，并解析出结构化字段（iOS）
- **日期** — 检测日期和时间，输出 ISO 8601 格式

- **原生精度** — 使用系统原生 API，而非正则表达式
- **控制器** — `DataDetectorController`（命令式）与 `DetectedEntitiesController`（响应式、边输入边检测）；两者都跟踪模型就绪状态，并在 Android 上自动下载模型
- **内联高亮** — `DataDetectorTextEditingController` 在用户输入时实时点亮 `TextField` 中的实体
- **实体胶囊** — `EntityRichText` + `EntityPill` 在只读场景下将检测到的实体渲染为发光的内联胶囊；样式可完全自定义或整体替换
- **多语言** — Android 端可从 15 种 ML Kit 语言模型中选择

## 安装

```bash
flutter pub add flutter_native_data_detector
```

### Android

ML Kit 实体提取模型（每种语言约 5.6MB）在用户设备上运行时下载。你可以通过 `NativeDataDetector.prepareModel()` 或 `DataDetectorController`（构造时自动下载）控制下载时机 —— 例如确保后续的 `detect()` 可以离线工作。如果不显式触发，模型会在第一次调用 `detect()` 时自动下载。

要求 `minSdkVersion 26`（ML Kit Entity Extraction 的要求）。

## 使用

### 函数

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

### 控制器

两个 `ChangeNotifier` 控制器对应两种场景：

- **`DataDetectorController`** — *命令式*。跟踪模型就绪状态，并提供一个由你自行调用的
  `detect` 方法（例如每条聊天消息调用一次）。
- **`DetectedEntitiesController`** — *响应式*。通过 `text` 喂入（不断变化的）字符串，它会
  以防抖方式随文本变化重新计算并暴露检测到的实体 —— 适合边输入边检测的场景。

两者在 Android 上都会自动下载模型，在 iOS 上为 no-op（始终就绪）。

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

### 内联高亮

`DataDetectorTextEditingController` 是一个 `TextEditingController`，在用户输入时
检测实体并进行内联高亮 —— 每种实体类型有自己的颜色和柔和的光晕 ——
同时输入框保持完全可编辑：

```dart
final controller = DataDetectorTextEditingController();

TextField(controller: controller);

// Structured results live on the embedded reactive controller:
controller.detection.addListener(() {
  print(controller.entities);
});
```

新检测到的实体会在 `highlightDuration`（默认 350ms）内淡入。
包本身只驱动**出现进度** `t`（线性 `0.0 → 1.0`）；
实体在任意 `t` 下的外观完全由你通过 `entityStyleBuilder` 决定 ——
可以自带曲线、自定义颜色，或忽略 `t` 使用静态样式：

```dart
DataDetectorTextEditingController(
  highlightDuration: const Duration(milliseconds: 500),
  entityStyleBuilder: (entity, base, t) => base.copyWith(
    color: Color.lerp(base.color, Colors.amber, Curves.easeOutCubic.transform(t)),
    decoration: TextDecoration.underline,
  ),
);
```

从轻量到完全控制的几个自定义入口：

1. `highlightDuration: Duration.zero` — 关闭过渡动画，`t` 始终为 `1.0`。
2. `entityStyleBuilder` — 完全控制任意进度下的内联样式。
3. 继承并重写 `buildTextSpan`，基于公开的
   `validEntities`（已做范围失效保护、已排序）构建 ——
   彻底替换渲染逻辑。

### 实体胶囊（只读展示）

在展示型场景 —— 消息气泡、预览 —— `EntityRichText` 会将每个检测到的实体
内联渲染在文本中，默认使用内置的 `EntityPill`：一个带实体类型图标、
发光的圆角胶囊，并在实体首次出现时淡入。（`WidgetSpan` 胶囊无法放进
可编辑的 `TextField`，这正是可编辑场景改用纯样式高亮的原因。）

```dart
EntityRichText(
  text: message,
  entities: entities, // from any detect() / controller
  style: const TextStyle(fontSize: 17, height: 2.0),
)
```

可以直接使用、调整胶囊样式，或整体替换：

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

实体范围在渲染前会先与 `text` 校验（即 `entities.validIn(text)` 扩展方法，
同样是公开 API），因此滞后于文本的检测结果永远不会渲染错位。

## API

### `NativeDataDetector.prepareModel({language})`

预下载实体检测模型，使后续的 `detect()` 可以离线运行。在 iOS 上是立即完成的 no-op —— `NSDataDetector` 内置于系统，无需下载模型。

返回 `Future<bool>` —— 模型就绪时为 `true`。

| 平台 | 行为 |
|----------|----------|
| **iOS** | No-op，立即返回 `true` |
| **Android** | 若尚未缓存，则下载对应语言的 ML Kit 模型（约 5.6MB）。首次调用需要联网。 |

### `NativeDataDetector.getModelStatus({language})`

返回指定语言模型的下载状态：`ModelStatus.ready` 或 `ModelStatus.notDownloaded`。iOS 上始终返回 `ready`。（纯查询永远不会返回 `downloading` 或 `error` —— 这两种状态只由 `DataDetectorController` 暴露。）

### `NativeDataDetector.isModelReady({language})`

`getModelStatus` 的便捷封装。当指定语言的模型可用时返回 `true`。

### `NativeDataDetector.detect(text, {types, language})`

使用原生平台 API 检测给定文本中的实体。

| 参数 | 类型 | 默认值 | 说明 |
|-----------|------|---------|-------------|
| `text` | `String` | — | 要分析的文本 |
| `types` | `List<DetectionType>?` | 全部类型 | 要检测的实体类型 |
| `language` | `ModelLanguage` | `en` | 使用哪种语言模型（仅 Android）。iOS 上忽略。 |

返回 `Future<List<DetectedEntity>>`。

### `DataDetectorController({language, autoPrepare})`

跟踪模型可用性的 `ChangeNotifier`，在 Android 上自动下载语言模型。iOS 上模型始终可用，因此 `status` 会稳定在 `ready`。

| 成员 | 类型 | 说明 |
|--------|------|-------------|
| `detect(text, {types})` | `Future<List<DetectedEntity>>` | 使用已配置的语言检测实体。 |
| `prepare()` | `Future<void>` | 手动（重新）下载已配置的语言模型。 |
| `status` | `ModelStatus` | `notDownloaded` / `downloading` / `ready` / `error`。 |
| `isReady` | `bool` | 当 `status == ModelStatus.ready` 时为 `true`。 |
| `error` | `Object?` | 最近一次准备模型的错误，无则为 `null`。 |
| `language` | `ModelLanguage` | 可变；修改后会重新检查/准备新模型。 |

### `DetectedEntitiesController({text, debounce, types, language, enabled, autoPrepare})`

响应式 `ChangeNotifier`：文本变化时设置 `text`，即可读回检测到的实体，自带防抖且取消安全（最新文本胜出）。内部自行管理模型就绪状态。

| 成员 | 类型 | 说明 |
|--------|------|-------------|
| `text` | `String` | 可变；设置后（重新）启动防抖计时器。 |
| `entities` | `List<DetectedEntity>` | 在防抖后的 `text` 中检测到的实体。 |
| `isDetecting` | `bool` | 最新文本的检测尚在进行时为 `true`。 |
| `status` | `ModelStatus` | 当前模型下载状态。 |
| `error` | `Object?` | 最近一次检测或模型错误，无则为 `null`。 |
| `enabled` | `bool` | 可变；为 `false` 时暂停检测并保留最后一次结果。 |
| `debounce` | `Duration` | 应用于 `text` 的防抖时长（默认 300ms）。 |
| `types` | `List<DetectionType>?` | 可变；要检测的实体类型（`null` = 全部）。 |
| `language` | `ModelLanguage` | 可变；选择 Android 模型并重新运行检测。 |

### `DataDetectorTextEditingController({text, debounce, types, language, enabled, autoPrepare, highlightDuration, entityStyleBuilder})`

一个对检测到的实体进行内联高亮、同时保持完全可编辑的 `TextEditingController`（只改样式、不改字符，因此光标和选区不受影响）。滞后于文本一个防抖间隔的检测结果会先做范围校验再应用样式，所以编辑永远不会导致错误高亮。

| 成员 | 类型 | 说明 |
|--------|------|-------------|
| `detection` | `DetectedEntitiesController` | 内嵌的响应式检测状态。 |
| `entities` | `List<DetectedEntity>` | 当前文本中检测到的实体。 |
| `validEntities` | `List<DetectedEntity>` | 经过范围失效保护、已排序的实体 —— 自定义 `buildTextSpan` 重写的安全基础。 |
| `highlightDuration` | `Duration` | 新检测实体的淡入时长（默认 350ms；`Duration.zero` 表示禁用）。 |
| `entityStyleBuilder` | `TextStyle Function(DetectedEntity, TextStyle base, double t)?` | 完全控制出现进度 `t`（线性 0→1）下的内联样式。 |

### `DetectedEntity`

| 属性 | 类型 | 说明 |
|----------|------|-------------|
| `type` | `DetectionType` | 检测到的实体类型 |
| `text` | `String` | 匹配到的文本子串 |
| `start` | `int` | 在原字符串中的起始索引（UTF-16 码元，即 Dart 字符串索引） |
| `end` | `int` | 在原字符串中的结束索引（不含） |
| `data` | `Map<String, String>` | 附加的结构化数据（见下文） |

### 各类型的实体数据

| 类型 | 数据字段 |
|------|-------------|
| `phoneNumber` | `{ phoneNumber }` |
| `link` | `{ url }` |
| `email` | `{ email }` |
| `address` | `{ street, city, state, zip, country }`（iOS）/ `{ address }`（Android） |
| `date` | `{ date }` ISO 8601 字符串 |

## 支持的语言

`language` 选项（枚举 `ModelLanguage`）选择 **Android** 端使用哪个 ML Kit 模型。在 iOS 上是 no-op，因为 `NSDataDetector` 与语言无关。每种语言是一个独立的约 5.6MB 端侧模型，按需下载。

| 代码 | 语言 | 代码 | 语言   | 代码 | 语言 |
| ---- | -------- | ---- | ---------- | ---- | -------- |
| `ar` | 阿拉伯语 | `it` | 意大利语   | `ru` | 俄语     |
| `nl` | 荷兰语   | `ja` | 日语       | `es` | 西班牙语 |
| `en` | 英语     | `ko` | 韩语       | `th` | 泰语     |
| `fr` | 法语     | `pl` | 波兰语     | `tr` | 土耳其语 |
| `de` | 德语     | `pt` | 葡萄牙语   | `zh` | 中文     |

## 平台差异

| 特性 | iOS | Android |
|---------|-----|---------|
| 引擎 | NSDataDetector | ML Kit Entity Extraction |
| 离线 | 始终可用 | `prepareModel()` 或首次 `detect()` 调用之后 |
| 模型下载 | 不需要 | 每种语言约 5.6MB，运行时端侧下载 |
| 语言选择 | 与语言无关（选项被忽略） | 15 种可选语言模型 |
| 地址解析 | 结构化字段 | 原始字符串 |
| 日期输出 | ISO 8601 | ISO 8601 |

## 环境要求

- iOS 13.0+
- Android API 26+（minSdk）—— ML Kit Entity Extraction 的要求

## 许可证

MIT
