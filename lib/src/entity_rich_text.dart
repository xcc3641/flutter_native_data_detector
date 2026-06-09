import 'package:flutter/widgets.dart';

import 'data_detector_text_editing_controller.dart' show defaultEntityColors;
import 'types.dart';

/// Default emoji icon per entity type, used by [EntityPill].
const Map<DetectionType, String> defaultEntityIcons = {
  DetectionType.phoneNumber: '☎️',
  DetectionType.link: '🔗',
  DetectionType.email: '✉️',
  DetectionType.address: '📍',
  DetectionType.date: '📅',
};

/// Builds the inline widget rendered for a detected entity in
/// [EntityRichText]. Return any widget; [EntityPill] is the built-in look.
typedef EntityWidgetBuilder =
    Widget Function(BuildContext context, DetectedEntity entity);

/// Renders [text] with each detected entity drawn inline in the flowing
/// text — by default as a glowing [EntityPill] (icon + colored label) that
/// fades in when the entity first appears.
///
/// This is the read-only companion to [DataDetectorTextEditingController]'s
/// editable inline highlighting: `WidgetSpan`-based pills cannot live inside
/// an editable `TextField` (they would change the character layout and break
/// cursor/selection mapping), so use this for display surfaces — message
/// bubbles, previews, detail views.
///
/// Entity ranges are validated against [text] before rendering (see
/// [DetectedEntityList.validIn]), so a result that lags the text never
/// mis-renders. Pass [entityBuilder] to replace the pill with your own
/// widget; each entity's subtree is keyed by type+text so appearance
/// animations only run when an entity is genuinely new.
///
/// ```dart
/// EntityRichText(
///   text: message,
///   entities: entities,
///   style: const TextStyle(fontSize: 17, height: 2.0),
/// )
/// ```
class EntityRichText extends StatelessWidget {
  const EntityRichText({
    super.key,
    required this.text,
    required this.entities,
    this.style,
    this.entityBuilder,
  });

  /// The full text to render.
  final String text;

  /// The entities detected in [text]. Invalid/stale ranges are skipped.
  final List<DetectedEntity> entities;

  /// Base style for the plain (non-entity) text. Defaults to the ambient
  /// [DefaultTextStyle].
  final TextStyle? style;

  /// Replaces the default [EntityPill] rendering per entity.
  final EntityWidgetBuilder? entityBuilder;

  @override
  Widget build(BuildContext context) {
    final children = <InlineSpan>[];
    var cursor = 0;

    for (final entity in entities.validIn(text)) {
      if (entity.start > cursor) {
        children.add(TextSpan(text: text.substring(cursor, entity.start)));
      }
      children.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          // Keyed by type+text so state (e.g. the fade-in) survives
          // re-detections and offset shifts; only new entities animate.
          child: KeyedSubtree(
            key: ValueKey('${entity.type.name} ${entity.text}'),
            child:
                entityBuilder?.call(context, entity) ??
                EntityPill(entity: entity),
          ),
        ),
      );
      cursor = entity.end;
    }
    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor)));
    }

    return Text.rich(TextSpan(children: children), style: style);
  }
}

/// The built-in entity decoration: a rounded pill with the entity-type icon
/// and the matched text, glowing in the entity's color, scaling and fading
/// in over [appearDuration] when first shown.
///
/// Every visual is overridable per instance; for a completely different
/// look, pass an [EntityRichText.entityBuilder] instead.
class EntityPill extends StatelessWidget {
  const EntityPill({
    super.key,
    required this.entity,
    this.color,
    this.icon,
    this.textStyle,
    this.appearDuration = const Duration(milliseconds: 350),
    this.appearCurve = Curves.easeOutBack,
  });

  final DetectedEntity entity;

  /// Pill accent color. Defaults to [defaultEntityColors] for the type.
  final Color? color;

  /// Leading icon text. Defaults to [defaultEntityIcons] for the type;
  /// empty string hides it.
  final String? icon;

  /// Merged over the default label style (entity color, 15, w700).
  final TextStyle? textStyle;

  /// Scale/fade-in length when the pill first appears.
  /// [Duration.zero] renders statically.
  final Duration appearDuration;

  /// Curve for the appearance animation.
  final Curve appearCurve;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? defaultEntityColors[entity.type]!;
    final icon = this.icon ?? defaultEntityIcons[entity.type]!;

    final pill = Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 12),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon.isNotEmpty) ...[
            Text(icon, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              entity.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ).merge(textStyle),
            ),
          ),
        ],
      ),
    );

    if (appearDuration == Duration.zero) return pill;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: appearDuration,
      curve: appearCurve,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
      ),
      child: pill,
    );
  }
}
