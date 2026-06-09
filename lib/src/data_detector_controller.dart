import 'package:flutter/foundation.dart';

import 'detector.dart';
import 'types.dart';

/// Controller for **imperative** data detection: it tracks model availability
/// and, on Android, downloads the language model automatically, then hands
/// you a [detect] method to call when you want (e.g. once per chat message).
///
/// The Flutter counterpart of react-native-data-detector's `useDataDetector`
/// hook. Listen to it (it is a [ChangeNotifier]) to react to [status] /
/// [error] changes, e.g. with `ListenableBuilder`.
///
/// For **reactive** detection of a changing string (as-you-type), use
/// [DetectedEntitiesController] instead.
///
/// On iOS the model is always available, so [status] settles on
/// [ModelStatus.ready] and `autoPrepare` has no effect.
class DataDetectorController extends ChangeNotifier {
  /// Creates the controller and, when [autoPrepare] is `true` (default),
  /// starts downloading the model for [language] if it is not already
  /// available (Android).
  DataDetectorController({
    ModelLanguage language = ModelLanguage.en,
    bool autoPrepare = true,
  })  : _language = language,
        _autoPrepare = autoPrepare {
    _checkModel();
  }

  ModelLanguage _language;
  final bool _autoPrepare;

  ModelStatus _status = ModelStatus.notDownloaded;
  Object? _error;

  // Bumped on every language change, prepare() and dispose() so that
  // late-resolving futures from a superseded run are ignored.
  int _epoch = 0;

  /// Which language model to use (Android only). Ignored on iOS.
  /// Changing this re-checks/prepares the model for the new language.
  ModelLanguage get language => _language;
  set language(ModelLanguage value) {
    if (value == _language) return;
    _language = value;
    _checkModel();
    notifyListeners();
  }

  /// Current model download state.
  ModelStatus get status => _status;

  /// `true` when the model is available and [detect] can run offline.
  bool get isReady => _status == ModelStatus.ready;

  /// The last preparation error, or `null`.
  Object? get error => _error;

  /// Detects entities in [text] using the controller's configured language.
  ///
  /// Safe to call before the model is ready — on Android the underlying call
  /// downloads the model on demand if needed.
  Future<List<DetectedEntity>> detect(
    String text, {
    List<DetectionType>? types,
  }) {
    return NativeDataDetector.detect(text, types: types, language: _language);
  }

  /// Manually (re)download the model for the configured language.
  Future<void> prepare() async {
    final epoch = ++_epoch;
    final language = _language;
    _error = null;
    _setStatus(ModelStatus.downloading);
    try {
      await NativeDataDetector.prepareModel(language: language);
      if (epoch == _epoch) _setStatus(ModelStatus.ready);
    } catch (e) {
      if (epoch == _epoch) _fail(e);
      rethrow;
    }
  }

  Future<void> _checkModel() async {
    final epoch = ++_epoch;
    final language = _language;
    _error = null;
    try {
      final current = await NativeDataDetector.getModelStatus(
        language: language,
      );
      if (epoch != _epoch) return;
      if (current == ModelStatus.ready) {
        _setStatus(ModelStatus.ready);
        return;
      }
      if (!_autoPrepare) {
        _setStatus(current);
        return;
      }
      _setStatus(ModelStatus.downloading);
      await NativeDataDetector.prepareModel(language: language);
      if (epoch == _epoch) _setStatus(ModelStatus.ready);
    } catch (e) {
      if (epoch == _epoch) _fail(e);
    }
  }

  void _setStatus(ModelStatus status) {
    if (_status == status) return;
    _status = status;
    notifyListeners();
  }

  // A new failure always notifies, even when the status is already `error`,
  // so listeners observe every fresh error object.
  void _fail(Object e) {
    _error = e;
    _status = ModelStatus.error;
    notifyListeners();
  }

  @override
  void dispose() {
    _epoch++;
    super.dispose();
  }
}
