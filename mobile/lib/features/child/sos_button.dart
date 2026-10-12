import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';

/// Press-and-hold SOS button. Holding (not tapping) prevents pocket presses,
/// but 2 seconds is short enough for a frightened child.
class SosButton extends StatefulWidget {
  const SosButton({super.key, required this.onTriggered, this.busy = false, this.holdDuration = const Duration(seconds: 2)});
  final VoidCallback onTriggered;
  final bool busy;
  final Duration holdDuration;

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton> with TickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(vsync: this, duration: widget.holdDuration)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        HapticFeedback.heavyImpact();
        widget.onTriggered();
        _hold.reset();
      }
    });
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _hold.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _down() {
    if (widget.busy) return;
    HapticFeedback.mediumImpact();
    _hold.forward(from: 0);
  }

  void _up() {
    if (_hold.status != AnimationStatus.completed) _hold.reverse();
  }

  @override
  Widget build(BuildContext context) {
    const size = 220.0;
    return Semantics(
      button: true,
      label: 'SOS emergency button. Press and hold for two seconds.',
      // Screen-reader users trigger it with the platform's long-press gesture.
      onLongPress: widget.busy ? null : widget.onTriggered,
      // Raw pointer events: the hold starts instantly and a parent scroll view can't steal it.
      child: Listener(
        onPointerDown: (_) => _down(),
        onPointerUp: (_) => _up(),
        onPointerCancel: (_) => _up(),
        child: AnimatedBuilder(
          animation: Listenable.merge([_hold, _pulse]),
          builder: (context, _) {
            final p = _pulse.value;
            return SizedBox(
              width: size + 60,
              height: size + 60,
              child: Stack(alignment: Alignment.center, children: [
                // Calm pulse rings
                for (final offset in [0.0, 0.5])
                  Opacity(
                    opacity: (1 - ((p + offset) % 1)) * 0.35,
                    child: Container(
                      width: size + 60 * ((p + offset) % 1),
                      height: size + 60 * ((p + offset) % 1),
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.sos),
                    ),
                  ),
                SizedBox(
                  width: size + 12,
                  height: size + 12,
                  child: CircularProgressIndicator(value: _hold.value, strokeWidth: 8, color: Colors.white, backgroundColor: Colors.transparent),
                ),
                Transform.scale(
                  scale: 1 - _hold.value * 0.06,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [Color(0xFFEF4444), AppColors.sos]),
                      boxShadow: [BoxShadow(color: Color(0x66DC2626), blurRadius: 30, offset: Offset(0, 10))],
                    ),
                    alignment: Alignment.center,
                    child: widget.busy
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Column(mainAxisSize: MainAxisSize.min, children: [
                            Text('SOS', style: TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w900, letterSpacing: 4)),
                            Text('HOLD', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, letterSpacing: 3)),
                          ]),
                  ),
                ),
              ]),
            );
          },
        ),
      ),
    );
  }
}
