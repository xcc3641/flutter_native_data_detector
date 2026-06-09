import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_native_data_detector/flutter_native_data_detector.dart';

import 'theme.dart';

/// "Data Detector" title + the native engine used on this platform.
class Header extends StatelessWidget {
  const Header({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Flutter Data Detector',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: C.text,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            Platform.isIOS ? 'NSDataDetector' : 'ML Kit Entity Extraction',
            style: const TextStyle(
              fontSize: 13,
              color: C.muted,
              fontFamily: 'Menlo',
              fontFamilyFallback: ['monospace'],
            ),
          ),
        ],
      ),
    );
  }
}

enum Mode { reactive, imperative }

/// "Live" / "On tap" segmented pill switching between the reactive
/// controller and imperative detect().
class ModeToggle extends StatelessWidget {
  const ModeToggle({super.key, required this.mode, required this.onChanged});

  final Mode mode;
  final ValueChanged<Mode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: C.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (value, label) in [
            (Mode.reactive, 'Live'),
            (Mode.imperative, 'On tap'),
          ])
            GestureDetector(
              onTap: () => onChanged(value),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 7,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: mode == value ? C.accent : null,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: mode == value ? Colors.white : C.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pill that replays the demo: clears the field and auto-types the sample
/// sentence so the entities light up one by one.
class DemoButton extends StatelessWidget {
  const DemoButton({super.key, required this.playing, required this.onTap});

  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: C.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
              size: 16,
              color: playing ? C.muted : C.accent,
            ),
            const SizedBox(width: 5),
            Text(
              playing ? 'Stop' : 'Demo',
              style: const TextStyle(
                color: C.text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pill showing the active Android language model; opens the sheet.
class LanguageButton extends StatelessWidget {
  const LanguageButton({
    super.key,
    required this.language,
    required this.onTap,
  });

  final ModelLanguage language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: C.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              languageName(language),
              style: const TextStyle(
                color: C.text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            const Text('▾', style: TextStyle(color: C.muted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet listing the 15 ML Kit language models.
Future<void> showLanguageSheet(
  BuildContext context, {
  required ModelLanguage selected,
  required ValueChanged<ModelLanguage> onSelect,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: C.surfaceHi,
    barrierColor: const Color(0x8C000000),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      side: BorderSide(color: C.border),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 6, bottom: 6),
              child: Text(
                'LANGUAGE MODEL',
                style: TextStyle(
                  color: C.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final (code, name) in languages)
                    InkWell(
                      onTap: () {
                        onSelect(code);
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 6,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: C.border, width: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                color: code == selected ? C.accent : C.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (code == selected)
                              const Text(
                                '✓',
                                style: TextStyle(
                                  color: C.accent,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Model download status row (hidden when ready).
class ModelStatusRow extends StatelessWidget {
  const ModelStatusRow({super.key, required this.status});

  final ModelStatus status;

  static const _labels = {
    ModelStatus.downloading: 'Downloading model…',
    ModelStatus.error: 'Model error',
    ModelStatus.notDownloaded: 'Model not downloaded',
  };

  @override
  Widget build(BuildContext context) {
    if (status == ModelStatus.ready) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          if (status == ModelStatus.downloading) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: C.muted),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            _labels[status] ?? status.name,
            style: const TextStyle(color: C.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// One detected entity: colored type tag + matched text.
class EntityChip extends StatelessWidget {
  const EntityChip({super.key, required this.entity});

  final DetectedEntity entity;

  @override
  Widget build(BuildContext context) {
    final color = typeColors[entity.type]!;

    return Container(
      constraints: const BoxConstraints(minWidth: 124, maxWidth: 220),
      height: 76,
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Text(
                typeLabels[entity.type]!.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            entity.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: C.text,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// "DETECTED · N" header + horizontal strip of entity chips, or a dashed
/// placeholder when empty.
///
/// Manages its own horizontal insets so the chips strip can scroll
/// full-bleed across the screen while the header stays aligned with the
/// rest of the content.
class DetectedList extends StatelessWidget {
  const DetectedList({
    super.key,
    required this.entities,
    required this.busy,
    required this.status,
    required this.mode,
  });

  final List<DetectedEntity> entities;
  final bool busy;
  final ModelStatus status;
  final Mode mode;

  @override
  Widget build(BuildContext context) {
    final preparing = Platform.isAndroid && status != ModelStatus.ready;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            screenPadding,
            0,
            screenPadding,
            10,
          ),
          child: Row(
            children: [
              Text(
                'DETECTED · ${entities.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: C.muted,
                  letterSpacing: 1,
                ),
              ),
              if (busy) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: C.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (entities.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: screenPadding),
            child: CustomPaint(
              painter: DashedBorderPainter(color: C.border, radius: 14),
              child: SizedBox(
                height: 76,
                width: double.infinity,
                child: Center(
                  child: Text(
                    preparing
                        ? 'Preparing model…'
                        : mode == Mode.reactive
                        ? 'Start typing to detect…'
                        : 'Tap Detect to analyze.',
                    style: const TextStyle(color: C.muted, fontSize: 13),
                  ),
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: screenPadding),
              itemCount: entities.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => EntityChip(entity: entities[i]),
            ),
          ),
      ],
    );
  }
}

/// Dashed rounded-rect border for the empty placeholder (Flutter's
/// [Border] only draws solid strokes).
class DashedBorderPainter extends CustomPainter {
  const DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );

    const dash = 5.0, gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color || radius != oldDelegate.radius;
}

/// Dark multiline text input.
class DetectInput extends StatelessWidget {
  const DetectInput({super.key, required this.controller, this.placeholder});

  final TextEditingController controller;
  final String? placeholder;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.border),
      ),
      constraints: const BoxConstraints(minHeight: 56, maxHeight: 130),
      child: TextField(
        controller: controller,
        maxLines: null,
        style: const TextStyle(color: C.text, fontSize: 16, height: 22 / 16),
        cursorColor: C.accent,
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          hintText: placeholder,
          hintStyle: const TextStyle(color: C.muted),
        ),
      ),
    );
  }
}

/// Accent "Detect" button used in imperative mode.
class DetectButton extends StatelessWidget {
  const DetectButton({
    super.key,
    required this.detecting,
    required this.isReady,
    required this.onPressed,
  });

  final bool detecting;
  final bool isReady;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final disabled = detecting || !isReady;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Opacity(
        opacity: disabled ? 0.5 : 1,
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: disabled ? null : onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: C.accent,
              disabledBackgroundColor: C.accent,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: detecting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    isReady ? 'Detect' : 'Preparing model…',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
