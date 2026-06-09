import 'dart:async';

import 'package:flutter/foundation.dart';

import 'data_detector_controller.dart';
import 'types.dart';

/// Controller for **reactive** data detection: feed it a (changing) string
/// via [text] and it exposes the detected entities, recomputed as the text
/// changes. Debounced and cancellation-safe (last write wins), so it is
/// suited to as-you-type input — set [text] from `TextField.onChanged` or a
/// `TextEditingController` listener.
///
/// The Flutter counterpart of react-native-data-detector's
/// `useDetectedEntities` hook. Listen to it (it is a [ChangeNotifier]) to
/// rebuild on [entities] / [isDetecting] / [status] changes.
///
/// Manages model readiness internally (auto-downloads on Android). For
/// **imperative** detection where you call `detect` yourself, use
/// [DataDetectorController] instead.
class DetectedEntitiesController extends ChangeNotifier {
  DetectedEntitiesController({
    String text = '',
    this.debounce = const Duration(milliseconds: 300),
    List<DetectionType>? types,
    ModelLanguage language = ModelLanguage.en,
    bool enabled = true,
    bool autoPrepare = true,
  })  : _text = text,
        _debouncedText = text,
        _types = types,
        _enabled = enabled {
    _model = DataDetectorController(
      language: language,
      autoPrepare: autoPrepare,
    );
    _model.addListener(_onModelChanged);
  }

  /// Debounce applied to [text] changes before detecting.
  final Duration debounce;

  late final DataDetectorController _model;
  ModelStatus _lastModelStatus = ModelStatus.notDownloaded;

  String _text;
  String _debouncedText;
  List<DetectionType>? _types;
  bool _enabled;

  List<DetectedEntity> _entities = const [];
  bool _isDetecting = false;
  Object? _detectError;

  Timer? _debounceTimer;

  // Bumped for every new detection run (and on clear/dispose) so that only
  // the latest run may publish its result.
  int _runId = 0;

  /// The text to detect entities in. Setting it (re)starts the debounce
  /// timer; detection runs [debounce] after the last change. Clearing the
  /// text clears the entities immediately — no debounce or model needed.
  String get text => _text;
  set text(String value) {
    if (value == _text) return;
    _text = value;
    if (!_enabled) return;
    _debounceTimer?.cancel();
    if (value.isEmpty) {
      _debouncedText = '';
      _clearResults();
      return;
    }
    _debounceTimer = Timer(debounce, () {
      _debouncedText = _text;
      _maybeDetect();
    });
  }

  /// Which entity types to detect. `null` means all types.
  /// Changing this re-runs detection on the current text.
  List<DetectionType>? get types => _types;
  set types(List<DetectionType>? value) {
    if (listEquals(value, _types)) return;
    _types = value;
    _maybeDetect();
  }

  /// Which language model to use (Android only). Ignored on iOS.
  /// Changing this re-checks/prepares the new model, then re-runs detection.
  ModelLanguage get language => _model.language;
  set language(ModelLanguage value) {
    if (value == _model.language) return;
    _model.language = value;
    _maybeDetect();
  }

  /// When `false`, detection is paused and the last result is kept.
  bool get enabled => _enabled;
  set enabled(bool value) {
    if (value == _enabled) return;
    _enabled = value;
    if (_enabled) {
      _debouncedText = _text;
      _maybeDetect();
    } else {
      _debounceTimer?.cancel();
    }
    notifyListeners();
  }

  /// Entities detected in the (debounced) [text]. Empty until the first
  /// result.
  List<DetectedEntity> get entities => _entities;

  /// `true` while a detection for the latest text is in flight.
  bool get isDetecting => _isDetecting;

  /// Current model download state.
  ModelStatus get status => _model.status;

  /// `true` when the model is available and detection can run offline.
  bool get isReady => _model.isReady;

  /// The last detection or model error, or `null`.
  Object? get error => _detectError ?? _model.error;

  void _onModelChanged() {
    // A ready model means pending text can now be detected.
    if (_model.status == ModelStatus.ready &&
        _lastModelStatus != ModelStatus.ready) {
      _maybeDetect();
    }
    _lastModelStatus = _model.status;
    notifyListeners();
  }

  void _clearResults() {
    _runId++;
    _entities = const [];
    _isDetecting = false;
    _detectError = null;
    notifyListeners();
  }

  void _maybeDetect() {
    if (!_enabled || !_model.isReady) return;

    if (_debouncedText.isEmpty) {
      _clearResults();
      return;
    }

    final runId = ++_runId;
    _isDetecting = true;
    _detectError = null;
    notifyListeners();

    _model.detect(_debouncedText, types: _types).then((result) {
      if (runId != _runId) return;
      _entities = result;
      _isDetecting = false;
      notifyListeners();
    }).catchError((Object e) {
      if (runId != _runId) return;
      _detectError = e;
      _isDetecting = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _runId++;
    _debounceTimer?.cancel();
    _model.removeListener(_onModelChanged);
    _model.dispose();
    super.dispose();
  }
}
