import 'package:flutter/material.dart';

class AppSurfaceCard extends StatelessWidget {
  const AppSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 24,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(225),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AppInfoPill extends StatelessWidget {
  const AppInfoPill({
    super.key,
    required this.icon,
    required this.label,
    this.inverse = false,
  });

  final IconData icon;
  final String label;
  final bool inverse;

  @override
  Widget build(BuildContext context) {
    final bg =
        inverse ? Colors.white.withAlpha(20) : Colors.black.withAlpha(10);
    final fg = inverse ? Colors.white : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: inverse ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class AppInlineBanner extends StatelessWidget {
  const AppInlineBanner({
    super.key,
    required this.message,
    required this.error,
    this.onDismiss,
  });

  final String message;
  final bool error;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final color = error ? const Color(0xFFB84C4C) : const Color(0xFF0F8B68);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Container(
        key: ValueKey('$error:$message'),
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withAlpha(14),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check_circle,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
            if (onDismiss != null)
              TextButton(
                onPressed: onDismiss,
                child: const Text('Хаах'),
              ),
          ],
        ),
      ),
    );
  }
}

class AppReveal extends StatelessWidget {
  const AppReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offsetY = 16,
  });

  final Widget child;
  final Duration delay;
  final double offsetY;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        final opacity = delay == Duration.zero ? value : value;
        return Transform.translate(
          offset: Offset(0, (1 - value) * offsetY),
          child: Opacity(
            opacity: opacity.clamp(0, 1),
            child: child,
          ),
        );
      },
    );
  }
}
