import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A button wrapper that provides immediate, smooth visual color-changing feedback
/// on touch down (without any device vibration).
class BouncyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double scaleDown;
  final Duration duration;
  final Color? pressOverlayColor;
  final BorderRadius? borderRadius;

  const BouncyButton({
    super.key,
    required this.child,
    this.onPressed,
    this.scaleDown = 0.99,
    this.duration = const Duration(milliseconds: 100),
    this.pressOverlayColor,
    this.borderRadius,
  });

  @override
  State<BouncyButton> createState() => _BouncyButtonState();
}

class _BouncyButtonState extends State<BouncyButton> {
  bool _isPressed = false;

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = true);
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = false);
    widget.onPressed?.call();
  }

  void _onTapCancel() {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = widget.borderRadius ?? BorderRadius.circular(12);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _isPressed ? widget.scaleDown : 1.0,
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        child: ClipRRect(
          borderRadius: effectiveRadius,
          child: Stack(
            alignment: Alignment.center,
            children: [
              widget.child,
              // Instant color changing press animation overlay (zero vibration)
              Positioned.fill(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 90),
                  curve: Curves.easeInOut,
                  color: _isPressed
                      ? (widget.pressOverlayColor ??
                          Colors.black.withValues(alpha: 0.14))
                      : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Production-ready Tactile Primary Button
/// Designed specifically for Career360 forms and actions.
class BouncyPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final String? loadingText;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final double height;
  final double? width;
  final double borderRadius;

  const BouncyPrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.loadingText,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.height = 52.0,
    this.width,
    this.borderRadius = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null && !isLoading;
    final Color bg = isEnabled
        ? (backgroundColor ?? AppTheme.primary)
        : (backgroundColor ?? AppTheme.primary).withValues(alpha: 0.6);

    return BouncyButton(
      onPressed: isEnabled ? onPressed : null,
      borderRadius: BorderRadius.circular(borderRadius),
      pressOverlayColor: const Color(0xFF0C3E9E).withValues(alpha: 0.35),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: width ?? double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: (backgroundColor ?? AppTheme.primary)
                        .withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isLoading
              ? Row(
                  key: const ValueKey('loading'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    if (loadingText != null) ...[
                      const SizedBox(width: 10),
                      Text(
                        loadingText!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ],
                )
              : Row(
                  key: const ValueKey('label'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      text,
                      style: TextStyle(
                        color: textColor ?? Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    if (icon != null) ...[
                      const SizedBox(width: 8),
                      Icon(icon, color: textColor ?? Colors.white, size: 18),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// Production-ready Tactile Outlined / Surface Button
/// Used for secondary actions, Google sign in, and cancels.
class BouncyOutlinedButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Widget? leading;
  final bool isLoading;
  final double height;
  final double? width;
  final Color borderColor;
  final Color? backgroundColor;
  final Color textColor;
  final double borderRadius;

  const BouncyOutlinedButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.leading,
    this.isLoading = false,
    this.height = 52.0,
    this.width,
    this.borderColor = const Color(0xFFD0D5DD),
    this.backgroundColor = Colors.white,
    this.textColor = const Color(0xFF101828),
    this.borderRadius = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null && !isLoading;

    return BouncyButton(
      onPressed: isEnabled ? onPressed : null,
      borderRadius: BorderRadius.circular(borderRadius),
      pressOverlayColor: const Color(0xFF155EEF).withValues(alpha: 0.08),
      child: Container(
        width: width ?? double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isLoading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF155EEF)),
                  ),
                )
              : Row(
                  key: const ValueKey('content'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: 12),
                    ],
                    Text(
                      text,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
