import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

// ---------------------------------------------------------------- painters

/// Pirate badge: skull and crossbones on a red rounded square.
class CrumbLogo extends StatelessWidget {
  final double size;
  const CrumbLogo({super.key, this.size = 30});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _LogoPainter(context.cc));
}

class _LogoPainter extends CustomPainter {
  final CC c;
  _LogoPainter(this.c);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 32);

    // red badge
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(1, 1, 30, 30),
        const Radius.circular(6),
      ),
      Paint()..color = c.accent,
    );

    final light = Paint()..color = c.accentInk;
    final dark = Paint()..color = c.accent;

    // crossbones (behind the skull)
    final bone = Paint()
      ..color = c.accentInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(6.5, 21.5), const Offset(25.5, 27.5), bone);
    canvas.drawLine(const Offset(25.5, 21.5), const Offset(6.5, 27.5), bone);

    // skull: head + jaw
    canvas.drawCircle(const Offset(16, 12.5), 7.2, light);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(11.6, 16.5, 8.8, 6.2),
        const Radius.circular(2),
      ),
      light,
    );

    // eyes and nose
    canvas.drawCircle(const Offset(13, 12.5), 1.9, dark);
    canvas.drawCircle(const Offset(19, 12.5), 1.9, dark);
    final nose = Path();
    nose.moveTo(16, 14.6);
    nose.lineTo(14.9, 17);
    nose.lineTo(17.1, 17);
    nose.close();
    canvas.drawPath(nose, dark);

    // teeth lines
    final teeth = Paint()
      ..color = c.accent
      ..strokeWidth = 0.9;
    canvas.drawLine(const Offset(14.2, 19), const Offset(14.2, 22.4), teeth);
    canvas.drawLine(const Offset(16, 19), const Offset(16, 22.4), teeth);
    canvas.drawLine(const Offset(17.8, 19), const Offset(17.8, 22.4), teeth);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) => true;
}

/// Gold doubloon with a star.
class CoinIcon extends StatelessWidget {
  final double size;
  const CoinIcon({super.key, this.size = 18});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _CoinPainter(context.cc.coin));
}

class _CoinPainter extends CustomPainter {
  final Color color;
  _CoinPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24);

    const rim = Color(0xFFB8861B);
    const mark = Color(0xFF8A6508);

    canvas.drawCircle(const Offset(12, 12), 10.5, Paint()..color = rim);
    canvas.drawCircle(const Offset(12, 12), 9, Paint()..color = color);

    // dotted ring
    final dot = Paint()..color = mark;
    for (var i = 0; i < 16; i++) {
      final a = i * 2 * math.pi / 16;
      canvas.drawCircle(
        Offset(12 + 6.5 * math.cos(a), 12 + 6.5 * math.sin(a)),
        0.55,
        dot,
      );
    }

    // star
    final star = Path();
    star.moveTo(12, 7.5);
    star.lineTo(13.4, 10.5);
    star.lineTo(16.6, 10.9);
    star.lineTo(14.2, 13.1);
    star.lineTo(14.9, 16.3);
    star.lineTo(12, 14.6);
    star.lineTo(9.1, 16.3);
    star.lineTo(9.8, 13.1);
    star.lineTo(7.4, 10.9);
    star.lineTo(10.6, 10.5);
    star.close();
    canvas.drawPath(star, dot);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CoinPainter old) => old.color != color;
}

/// Circular progress ring (profile level ring, AI score ring).
class RingPainter extends CustomPainter {
  final double frac, stroke;
  final Color track, color;
  RingPainter({required this.frac, required this.track, required this.color, this.stroke = 7});
  @override
  void paint(Canvas canvas, Size size) {
    final r = (size.width - stroke) / 2;
    final ctr = Offset(size.width / 2, size.height / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(ctr, r, p..color = track);
    canvas.drawArc(Rect.fromCircle(center: ctr, radius: r), -math.pi / 2, 2 * math.pi * frac, false, p..color = color);
  }

  @override
  bool shouldRepaint(covariant RingPainter o) => o.frac != frac || o.color != color || o.track != track;
}

// ---------------------------------------------------------------- ticking

/// Rebuilds every second. Used for sprint countdowns.
class TickBuilder extends StatefulWidget {
  final WidgetBuilder builder;
  const TickBuilder({super.key, required this.builder});
  @override
  State<TickBuilder> createState() => _TickBuilderState();
}

class _TickBuilderState extends State<TickBuilder> {
  late final Timer _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

// ---------------------------------------------------------------- atoms

enum BtnStyle { normal, primary, ok }

/// Wooden-plank button: rounded, dark outline, blackletter label.
class Btn extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final BtnStyle style;
  final bool small, expand;
  const Btn(this.label, {super.key, this.icon, this.onPressed, this.style = BtnStyle.normal, this.small = false, this.expand = false});

  @override
  Widget build(BuildContext context) {
    final c = context.cc;
    final bool isPrimary = style == BtnStyle.primary;
    final bool isOk = style == BtnStyle.ok;
    final Color bg = isPrimary ? c.accent : (isOk ? c.okSoft : c.surface);
    final Color fg = isPrimary ? c.accentInk : (isOk ? c.ok : c.ink);
    final Color border = isPrimary ? c.ink : (isOk ? c.ok : c.line2);
    final double lift = (isPrimary && onPressed != null) ? 3.0 : 0.0;
    final double pad = small ? 12.0 : 16.0;
    final double padV = small ? 7.0 : 11.0;
    final double iconSize = small ? 15.0 : 18.0;
    final double fontSize = small ? 15.0 : 17.0;
    final TextStyle labelStyle = T.disp(fontSize, w: FontWeight.w400, color: fg, h: 1.2);

    final List<Widget> inner = [];
    if (icon != null) {
      inner.add(Icon(icon, size: iconSize, color: fg));
      inner.add(const SizedBox(width: 8));
    }
    inner.add(Flexible(child: Text(label, textAlign: TextAlign.center, style: labelStyle)));

    return Opacity(
      opacity: onPressed == null ? 0.62 : 1.0,
      child: Material(
        color: bg,
        elevation: lift,
        shadowColor: c.ink.o(0.5),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: border, width: isPrimary ? 1.5 : 1.0),
        ),
        child: InkWell(
          onTap: onPressed,
          hoverColor: isPrimary ? Colors.white.o(0.12) : c.surface2,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: pad, vertical: padV),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: inner,
            ),
          ),
        ),
      ),
    );
  }
}

class IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  const IconBtn(this.icon, this.tooltip, {super.key, this.onPressed});
  @override
  Widget build(BuildContext context) {
    final c = context.cc;
    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: onPressed == null ? 0.4 : 1.0,
        child: Material(
          color: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: BorderSide(color: c.line2)),
          child: InkWell(
            onTap: onPressed,
            child: Padding(padding: const EdgeInsets.all(8), child: Icon(icon, size: 16, color: c.ink)),
          ),
        ),
      ),
    );
  }
}

class Tag extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const Tag(this.label, this.color, {super.key, this.icon});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: color.o(0.10),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
          Text(label, style: T.body(12, w: FontWeight.w600, color: color)),
        ]),
      );
}

class Pill extends StatelessWidget {
  final String label;
  final bool hot;
  const Pill(this.label, {super.key, this.hot = false});
  @override
  Widget build(BuildContext context) {
    final c = context.cc;
    final col = hot ? c.accent : c.ink2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: hot ? c.accentSoft : null,
          border: Border.all(color: hot ? c.accent : c.line),
          borderRadius: BorderRadius.circular(5)),
      child: Text(label, style: T.body(12.5, w: FontWeight.w600, color: col)),
    );
  }
}

class SkillChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final bool outlined;
  const SkillChip(this.label, {super.key, this.icon, this.color, this.outlined = false});
  @override
  Widget build(BuildContext context) {
    final c = context.cc;
    final col = color ?? c.ink3;
    return Container(
      padding: outlined
          ? const EdgeInsets.symmetric(horizontal: 7, vertical: 2)
          : const EdgeInsets.only(right: 4, top: 2, bottom: 2),
      decoration: outlined
          ? BoxDecoration(border: Border.all(color: col), borderRadius: BorderRadius.circular(5))
          : null,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: col), const SizedBox(width: 4)],
        Text(label, style: T.body(12.5, w: FontWeight.w600, color: col)),
      ]),
    );
  }
}

class Bar extends StatelessWidget {
  final double frac;
  final Color color;
  final double height;
  const Bar(this.frac, {super.key, required this.color, this.height = 5});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: Container(
          height: height,
          color: context.cc.line,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(widthFactor: frac.clamp(0.0, 1.0), child: Container(color: color)),
        ),
      );
}

/// Section panel. Unboxed = top rule; boxed = parchment card with soft shadow.
class Panel extends StatelessWidget {
  final Widget child;
  final bool boxed;
  const Panel({super.key, required this.child, this.boxed = false});
  @override
  Widget build(BuildContext context) {
    final c = context.cc;
    return Container(
      width: double.infinity,
      padding: boxed ? const EdgeInsets.all(20) : const EdgeInsets.only(top: 28),
      decoration: boxed
          ? BoxDecoration(
              color: c.surface,
              border: Border.all(color: c.line2, width: 1.2),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: c.ink.o(0.12), blurRadius: 10, offset: const Offset(0, 4))],
            )
          : BoxDecoration(border: Border(top: BorderSide(color: c.line2))),
      child: child,
    );
  }
}

class PanelHead extends StatelessWidget {
  final String title;
  final String? sub;
  const PanelHead(this.title, {super.key, this.sub});
  @override
  Widget build(BuildContext context) {
    final c = context.cc;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: T.disp(26)),
      if (sub != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(sub!, style: T.body(14, color: c.ink2))),
    ]);
  }
}

class Hint extends StatelessWidget {
  final String text;
  final bool mono;
  const Hint(this.text, {super.key, this.mono = false});
  @override
  Widget build(BuildContext context) => Text(text,
      style: (mono ? T.mono(12.5) : T.body(12.5)).copyWith(color: context.cc.ink3));
}

class Notice extends StatelessWidget {
  final bool good;
  final String text;
  const Notice(this.text, {super.key, required this.good});
  @override
  Widget build(BuildContext context) {
    final c = context.cc;
    final col = good ? c.ok : c.bad;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: good ? c.okSoft : c.badSoft,
        border: Border.all(color: col.o(0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(good ? Icons.check : Icons.lock_outline, size: 18, color: col),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: T.body(13.5, w: FontWeight.w600, color: col))),
      ]),
    );
  }
}

/// Segmented selector (sort, multiplier, builders per task, sprint).
class Seg<V> extends StatelessWidget {
  final Map<V, String> options;
  final V value;
  final ValueChanged<V> onChanged;
  const Seg({super.key, required this.options, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final c = context.cc;
    return Wrap(children: [
      for (final e in options.entries)
        InkWell(
          onTap: () => onChanged(e.key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: e.key == value ? c.surface2 : null,
              border: Border(bottom: BorderSide(color: e.key == value ? c.accent : Colors.transparent, width: 2)),
            ),
            child: Text(e.value,
                style: T.body(13, w: FontWeight.w600, color: e.key == value ? c.ink : c.ink2)),
          ),
        ),
    ]);
  }
}

class FilterChipX extends StatelessWidget {
  final String label;
  final int count;
  final bool on;
  final VoidCallback onTap;
  const FilterChipX(this.label, this.count, this.on, this.onTap, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.cc;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: on ? c.ink : c.surface.o(0.6),
          border: Border.all(color: on ? c.ink : c.line2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: T.disp(15, w: FontWeight.w400, color: on ? c.bg : c.ink2)),
          const SizedBox(width: 6),
          Text('$count', style: T.mono(12, color: (on ? c.bg : c.ink2).o(0.7))),
        ]),
      ),
    );
  }
}

void toast(BuildContext context, String msg) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(content: Text(msg), duration: const Duration(milliseconds: 3200)));
}
