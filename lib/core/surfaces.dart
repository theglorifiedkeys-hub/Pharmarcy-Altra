import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'lucide_icons.dart';
import '../app/theme.dart';

const motionCurve = Cubic(.16, 1, .3, 1);
const spring = SpringDescription(mass: 1, stiffness: 350, damping: 22);

class AmbientMintBackdrop extends StatelessWidget {
  const AmbientMintBackdrop({
    super.key,
    this.center = const Alignment(.65, -.04),
  });
  final Alignment center;
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.canvasBase,
          gradient: RadialGradient(
            center: center,
            radius: .77,
            colors: [
              AppColors.auraMintWarm.withValues(alpha: .63),
              AppColors.auraMintLight.withValues(alpha: .64),
              AppColors.canvasBase,
            ],
            stops: const [0, .49, 1],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(1.15, -.9),
              radius: .72,
              colors: [
                AppColors.auraMintLight.withValues(alpha: .65),
                AppColors.auraMintLight.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 28,
    this.padding = EdgeInsets.zero,
    this.blur = false,
    this.shadow = true,
  });
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool blur, shadow;
  @override
  Widget build(BuildContext context) {
    final corners = BorderRadius.circular(radius);
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: corners,
        border: Border.all(color: Colors.white.withValues(alpha: .85)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: .86),
            Colors.white.withValues(alpha: .69),
          ],
        ),
      ),
      child: child,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: corners,
        boxShadow: shadow
            ? const [
                BoxShadow(
                  color: Color(0x14176047),
                  blurRadius: 24,
                  offset: Offset(0, 9),
                ),
              ]
            : null,
      ),
      child: blur
          ? ClipRRect(
              borderRadius: corners,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: content,
              ),
            )
          : content,
    );
  }
}

class SpringScaleTap extends StatefulWidget {
  const SpringScaleTap({
    super.key,
    required this.child,
    required this.onTap,
    this.label,
    this.selected,
  });
  final Widget child;
  final VoidCallback onTap;
  final String? label;
  final bool? selected;
  @override
  State<SpringScaleTap> createState() => _SpringScaleTapState();
}

class _SpringScaleTapState extends State<SpringScaleTap>
    with SingleTickerProviderStateMixin {
  late final _scale = AnimationController.unbounded(vsync: this, value: 1);
  void release() {
    if (!MediaQuery.disableAnimationsOf(context))
      _scale.animateWith(SpringSimulation(spring, _scale.value, 1, 0));
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    selected: widget.selected,
    button: true,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: widget.onTap,
          onTapDown: (_) {
            HapticFeedback.lightImpact();
            if (!MediaQuery.disableAnimationsOf(context))
              _scale.animateTo(
                .95,
                duration: const Duration(milliseconds: 110),
                curve: Curves.easeOutCubic,
              );
          },
          onTapUp: (_) => release(),
          onTapCancel: release,
          child: ScaleTransition(scale: _scale, child: widget.child),
        ),
      ),
    ),
  );
}

class PillButton extends StatelessWidget {
  const PillButton(
    this.label,
    this.onTap, {
    super.key,
    this.icon,
    this.dark = true,
    this.height = 50,
    this.trailing,
  });
  final String label;
  final VoidCallback onTap;
  final IconData? icon, trailing;
  final bool dark;
  final double height;
  @override
  Widget build(BuildContext context) => SpringScaleTap(
    onTap: onTap,
    child: Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: dark
            ? AppColors.inkPrimary
            : Colors.white.withValues(alpha: .85),
        borderRadius: BorderRadius.circular(999),
        border: dark ? null : Border.all(color: Colors.white),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 16,
              color: dark ? Colors.white : AppColors.inkPrimary,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: dark ? Colors.white : AppColors.inkPrimary,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Icon(
              trailing,
              size: 16,
              color: dark ? Colors.white : AppColors.inkPrimary,
            ),
          ],
        ],
      ),
    ),
  );
}

class RoundAction extends StatelessWidget {
  const RoundAction(
    this.icon,
    this.label,
    this.onTap, {
    super.key,
    this.size = 44,
    this.dark = false,
    this.blur = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;
  final bool dark, blur;
  @override
  Widget build(BuildContext context) => SpringScaleTap(
    label: label,
    onTap: onTap,
    child: SizedBox.square(
      dimension: size,
      child: dark
          ? DecoratedBox(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.inkPrimary,
              ),
              child: Icon(icon, size: 18, color: Colors.white),
            )
          : GlassSurface(
              radius: 999,
              blur: blur,
              shadow: false,
              child: Icon(icon, size: size < 36 ? 15 : 19),
            ),
    ),
  );
}

class FlowHeader extends StatelessWidget {
  const FlowHeader(
    this.title, {
    super.key,
    required this.onOptions,
    this.ai = false,
    this.blur = false,
  });
  final String title;
  final VoidCallback onOptions;
  final bool ai, blur;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      RoundAction(
        LucideIcons.chevronLeft,
        'Back',
        () => Navigator.maybePop(context),
        blur: blur,
      ),
      Hero(
        tag: ai && !MediaQuery.disableAnimationsOf(context)
            ? 'ai-orb'
            : 'static-flow-title',
        flightShuttleBuilder: (_, _, _, _, destination) => FittedBox(
          fit: BoxFit.contain,
          child: (destination.widget as Hero).child,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: GlassSurface(
            radius: 999,
            blur: blur,
            shadow: false,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (ai) ...[
                  const CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.inkPrimary,
                    child: Icon(
                      LucideIcons.sparkles,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(title, style: AppTypography.label),
              ],
            ),
          ),
        ),
      ),
      RoundAction(LucideIcons.ellipsis, 'Options', onOptions, blur: blur),
    ],
  );
}

class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.child, this.delay = 0});
  final Widget child;
  final int delay;
  @override
  Widget build(BuildContext context) => MediaQuery.disableAnimationsOf(context)
      ? child
      : TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 320 + delay),
          curve: Interval(delay / (320 + delay), 1, curve: motionCurve),
          tween: Tween(begin: 0, end: 1),
          child: child,
          builder: (_, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 12 * (1 - value)),
              child: Transform.scale(scale: .97 + .03 * value, child: child),
            ),
          ),
        );
}

Future<T?> showPanel<T>(
  BuildContext context,
  String title,
  List<Widget> children,
) => showModalBottomSheet<T>(
  context: context,
  showDragHandle: true,
  useSafeArea: true,
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: 500),
  builder: (context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        0,
        22,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppTypography.title),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    ),
  ),
);
