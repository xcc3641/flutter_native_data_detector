import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_data_detector/flutter_native_data_detector.dart';

import 'theme.dart';
import 'widgets.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Data Detector',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const DataDetectorScreen(),
    );
  }
}

class DataDetectorScreen extends StatefulWidget {
  const DataDetectorScreen({super.key});

  @override
  State<DataDetectorScreen> createState() => _DataDetectorScreenState();
}

class _DataDetectorScreenState extends State<DataDetectorScreen> {
  ModelLanguage _language = ModelLanguage.en;
  Mode _mode = Mode.reactive;

  // Imperative controller: model lifecycle + a detect() you call yourself.
  late final _detector = DataDetectorController(language: _language);

  // Text controller with built-in reactive detection: highlights entities
  // inline as you type (paused in "On tap" mode).
  late final _editor = DataDetectorTextEditingController(
    text: sampleText,
    language: _language,
    debounce: const Duration(milliseconds: 200),
  );

  List<DetectedEntity> _tappedEntities = const [];
  bool _detecting = false;

  Timer? _demoTimer;
  bool get _demoPlaying => _demoTimer != null;

  @override
  void dispose() {
    _demoTimer?.cancel();
    _detector.dispose();
    _editor.dispose();
    super.dispose();
  }

  /// Clears the field and auto-types [demoText] so the entities light up
  /// one by one. Tapping again stops the replay.
  void _toggleDemo() {
    if (_demoPlaying) {
      _demoTimer?.cancel();
      _demoTimer = null;
      setState(() {});
      return;
    }
    _setMode(Mode.reactive); // the live effect is the point of the demo
    _editor.clear();
    _typeDemo(1);
    setState(() {});
  }

  void _typeDemo(int length) {
    _editor.value = TextEditingValue(
      text: demoText.substring(0, length),
      selection: TextSelection.collapsed(offset: length),
    );
    if (length >= demoText.length) {
      _demoTimer = null;
      setState(() {});
      return;
    }
    // Pause at punctuation like a human typist — long enough for the
    // debounced detection to land, so entities animate in while typing
    // instead of all at once at the end.
    final justTyped = demoText[length - 1];
    final delay = switch (justTyped) {
      '.' || ',' => const Duration(milliseconds: 550),
      _ => const Duration(milliseconds: 40),
    };
    _demoTimer = Timer(delay, () => _typeDemo(length + 1));
  }

  Future<void> _handleDetect() async {
    setState(() => _detecting = true);
    try {
      final entities = await _detector.detect(_editor.text);
      setState(() => _tappedEntities = entities);
    } catch (_) {
      setState(() => _tappedEntities = const []);
    } finally {
      setState(() => _detecting = false);
    }
  }

  void _setMode(Mode mode) {
    setState(() => _mode = mode);
    _editor.detection.enabled = mode == Mode.reactive;
  }

  void _setLanguage(ModelLanguage language) {
    setState(() => _language = language);
    _detector.language = language;
    _editor.detection.language = language;
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid = Platform.isAndroid;

    return Scaffold(
      backgroundColor: C.bg,
      resizeToAvoidBottomInset: true,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
            child: ListenableBuilder(
              listenable: Listenable.merge([_detector, _editor]),
              builder: (context, _) {
                final entities = _mode == Mode.reactive
                    ? _editor.entities
                    : _tappedEntities;
                final busy = _mode == Mode.reactive
                    ? _editor.detection.isDetecting
                    : _detecting;

                // Sections pad themselves so the chips strip inside
                // DetectedList can scroll full-bleed.
                const pad = EdgeInsets.symmetric(horizontal: screenPadding);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(padding: pad, child: Header()),
                    Padding(
                      padding: pad,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              DemoButton(
                                playing: _demoPlaying,
                                onTap: _toggleDemo,
                              ),
                              if (isAndroid) ...[
                                const SizedBox(width: 8),
                                LanguageButton(
                                  language: _language,
                                  onTap: () => showLanguageSheet(
                                    context,
                                    selected: _language,
                                    onSelect: _setLanguage,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          ModeToggle(mode: _mode, onChanged: _setMode),
                        ],
                      ),
                    ),
                    if (isAndroid)
                      Padding(
                        padding: pad,
                        child: ModelStatusRow(status: _detector.status),
                      ),
                    // Center canvas: the text rendered with glowing entity
                    // pills, reflowing live as you type.
                    Expanded(
                      child: Padding(
                        padding: pad,
                        child: Center(
                          child: SingleChildScrollView(
                            // The package's built-in pill style; pass
                            // entityBuilder for a custom look.
                            child: EntityRichText(
                              text: _editor.text,
                              entities: entities,
                              style: const TextStyle(
                                color: C.text,
                                fontSize: 17,
                                height: 2.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DetectedList(
                      entities: entities,
                      busy: busy,
                      status: _detector.status,
                      mode: _mode,
                    ),
                    Padding(
                      padding: pad,
                      child: DetectInput(
                        controller: _editor,
                        placeholder:
                            'Type something with a phone, email, link, address or date…',
                      ),
                    ),
                    if (_mode == Mode.imperative)
                      Padding(
                        padding: pad,
                        child: DetectButton(
                          detecting: _detecting,
                          isReady: _detector.isReady,
                          onPressed: _handleDetect,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
