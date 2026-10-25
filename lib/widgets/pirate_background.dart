import 'dart:math';

import 'package:flutter/material.dart';

/// Pirate-themed backdrop: gradient + faint pirate icons
/// + a little sailing ship bobbing on moving waves, with slow clouds.
/// Purely visual. It ignores taps, so nothing in the app changes.
class PirateBackground extends StatefulWidget {
  final Widget child;
  const PirateBackground({super.key, required this.child});

  @override
  State<PirateBackground> createState() => _PirateBackgroundState();
}

class _PirateBackgroundState extends State<PirateBackground>
    with SingleTickerProviderStateMixin {
  static const _icons = [
    Icons.sailing,
    Icons.anchor,
    Icons.explore,
    Icons.map_outlined,
    Icons.flag_outlined,
    Icons.paid_outlined,
    Icons.waves,
    Icons.diamond_outlined,
    Icons.key_outlined,
    Icons.directions_boat_outlined,
  ];

  // One full loop = 120 seconds. Every movement uses a whole number of
  // cycles inside the loop, so the animation never "jumps" when it restarts.
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 120),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // If the phone has "reduce motion" turned on, keep the picture still.
    final still = MediaQuery.of(context).disableAnimations;
    if (still) {
      _ctrl.stop();
      _ctrl.value = 0.15;
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final gradient = dark
        ? const [Color(0xFF0A1A2A), Color(0xFF123247)]
        : const [Color(0xFFF8EBCF), Color(0xFFE8D2A6)];
    final iconColor = dark ? const Color(0x12FFFFFF) : const Color(0x175A3A1A);

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: gradient,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: RepaintBoundary(
            child: IgnorePointer(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const cell = 110.0;
                  final rnd = Random(7); // fixed seed = same layout every time
                  final cols = (constraints.maxWidth / cell).ceil();
                  final rows = (constraints.maxHeight / cell).ceil();
                  final items = <Widget>[];
                  for (var r = 0; r < rows; r++) {
                    for (var col = 0; col < cols; col++) {
                      items.add(
                        Positioned(
                          left: col * cell + rnd.nextDouble() * 40,
                          top: r * cell + rnd.nextDouble() * 40,
                          child: Transform.rotate(
                            angle: (rnd.nextDouble() - 0.5) * 0.9,
                            child: Icon(
                              _icons[rnd.nextInt(_icons.length)],
                              size: 30 + rnd.nextDouble() * 22,
                              color: iconColor,
                            ),
                          ),
                        ),
                      );
                    }
                  }
                  return Stack(children: items);
                },
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: RepaintBoundary(
            child: IgnorePointer(
              child: CustomPaint(painter: _SeaPainter(_ctrl, dark)),
            ),
          ),
        ),
        Positioned.fill(child: widget.child),
      ],
    );
  }
}

/// Draws clouds, three layers of waves, and the ship.
class _SeaPainter extends CustomPainter {
  final Animation<double> anim;
  final bool dark;
  _SeaPainter(this.anim, this.dark) : super(repaint: anim);

  static const double _tau = 2 * pi;

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value; // 0..1 over 120 seconds
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    _drawClouds(canvas, size, t);

    final seaH = max(90.0, min(170.0, h * 0.16));
    final top = h - seaH;
    final len = max(220.0, w * 0.35);

    final backBase = top + seaH * 0.15;
    final midBase = top + seaH * 0.38;
    final frontBase = top + seaH * 0.64;

    final backPhase = _tau * 24 * t;
    final midPhase = -_tau * 30 * t;
    final frontPhase = _tau * 40 * t;

    // 1) back wave
    _drawWave(
      canvas,
      size,
      _waveLine(w, backBase, 6, len, backPhase),
      dark ? const Color(0x3340A0C0) : const Color(0x301D5C7A),
      dark ? const Color(0x4440A0C0) : const Color(0x401D5C7A),
    );

    // 2) the ship, sitting on the back wave
    final shipX = w * (w < 500 ? 0.68 : 0.76);
    final shipScale = max(0.7, min(1.4, w * 0.2 / 100));
    final waveY = _waveY(shipX, backBase, 6, len, backPhase);
    final bob = sin(_tau * 30 * t) * 3;
    final tilt = sin(_tau * 20 * t + 1) * 0.05;
    final flutter = sin(_tau * 60 * t);

    canvas.save();
    canvas.translate(shipX, waveY + seaH * 0.12 + bob);
    canvas.rotate(tilt);
    canvas.scale(shipScale);
    canvas.saveLayer(
      const Rect.fromLTWH(-80, -130, 170, 170),
      Paint()..color = const Color(0xCCFFFFFF), // ship is 80% solid
    );
    _drawShip(canvas, flutter);
    canvas.restore();
    canvas.restore();

    // 3) middle and front waves cover the bottom of the ship
    _drawWave(
      canvas,
      size,
      _waveLine(w, midBase, 8, len * 1.3, midPhase),
      dark ? const Color(0x3A2B7A9A) : const Color(0x401D5C7A),
      dark ? const Color(0x5540A0C0) : const Color(0x551D5C7A),
    );
    _drawWave(
      canvas,
      size,
      _waveLine(w, frontBase, 10, len * 0.9, frontPhase),
      dark ? const Color(0x4A1E5F7D) : const Color(0x501D5C7A),
      dark ? const Color(0x6640A0C0) : const Color(0x661D5C7A),
    );
  }

  double _waveY(double x, double base, double amp, double len, double phase) =>
      base + amp * sin(_tau * x / len + phase);

  Path _waveLine(double w, double base, double amp, double len, double phase) {
    final p = Path()..moveTo(0, _waveY(0, base, amp, len, phase));
    for (double x = 6; x <= w + 6; x += 6) {
      p.lineTo(x, _waveY(x, base, amp, len, phase));
    }
    return p;
  }

  void _drawWave(Canvas canvas, Size size, Path line, Color fill, Color edge) {
    final fillPath = Path.from(line)
      ..lineTo(size.width + 6, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fillPath, Paint()..color = fill);
    canvas.drawPath(
      line,
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  // ---------------------------------------------------------------- clouds

  void _drawClouds(Canvas canvas, Size size, double t) {
    final paint = Paint()
      ..color = dark ? const Color(0x14FFFFFF) : const Color(0x80FFFFFF);
    // y position (fraction of height), size, start offset, cycles per loop
    const specs = <List<double>>[
      [0.08, 1.0, 0.00, 1.0],
      [0.20, 0.7, 0.45, 2.0],
      [0.32, 1.2, 0.75, 1.0],
    ];
    for (final s in specs) {
      final scale = s[1];
      final cw = 150 * scale;
      final progress = (t * s[3] + s[2]) % 1.0;
      final x = progress * (size.width + cw * 2) - cw;
      _drawCloud(canvas, Offset(x, size.height * s[0]), scale, paint);
    }
  }

  void _drawCloud(Canvas canvas, Offset o, double s, Paint paint) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: o.translate(0, 10 * s),
            width: 130 * s,
            height: 26 * s,
          ),
          Radius.circular(13 * s),
        ),
      )
      ..addOval(Rect.fromCircle(center: o.translate(-30 * s, 2 * s), radius: 18 * s))
      ..addOval(Rect.fromCircle(center: o.translate(0, -8 * s), radius: 26 * s))
      ..addOval(Rect.fromCircle(center: o.translate(32 * s, 3 * s), radius: 17 * s));
    canvas.drawPath(path, paint);
  }

  // ------------------------------------------------------------------ ship
  // Drawn in a box about 100 units wide. (0,0) = middle of the ship at the water.

  void _drawShip(Canvas canvas, double flutter) {
    final outline = dark ? const Color(0xFFCBB98E) : const Color(0xFF2B1A0E);
    const hullColor = Color(0xFF5A3A1A);
    final sailColor = dark ? const Color(0xFFE8D8B0) : const Color(0xFFF6E9C9);
    final skullColor = dark ? const Color(0xFF12303F) : const Color(0xFF2B1A0E);
    final flagColor = dark ? const Color(0xFFE5483A) : const Color(0xFF9E1B1B);

    final line = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final fillHull = Paint()..color = hullColor;
    final fillSail = Paint()..color = sailColor;
    final fillFlag = Paint()..color = flagColor;
    final fillSkull = Paint()..color = skullColor;

    // masts and bowsprit
    final mast = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(4, -10), const Offset(4, -94), mast);
    canvas.drawLine(const Offset(46, -8), const Offset(68, -22), mast);

    // upper sail
    final sail1 = Path()
      ..moveTo(-24, -86)
      ..lineTo(32, -86)
      ..quadraticBezierTo(40, -62, 31, -42)
      ..lineTo(-22, -42)
      ..quadraticBezierTo(-31, -62, -24, -86)
      ..close();
    canvas.drawPath(sail1, fillSail);
    canvas.drawPath(sail1, line);

    // lower sail
    final sail2 = Path()
      ..moveTo(-30, -37)
      ..lineTo(38, -37)
      ..quadraticBezierTo(46, -22, 37, -12)
      ..lineTo(-28, -12)
      ..quadraticBezierTo(-37, -24, -30, -37)
      ..close();
    canvas.drawPath(sail2, fillSail);
    canvas.drawPath(sail2, line);

    // little skull and crossbones on the upper sail
    canvas.drawCircle(const Offset(4, -68), 7, fillSkull);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0.5, -63, 7, 5),
        const Radius.circular(1.5),
      ),
      fillSkull,
    );
    canvas.drawCircle(const Offset(1.6, -69), 1.8, fillSail);
    canvas.drawCircle(const Offset(6.4, -69), 1.8, fillSail);
    final bones = Paint()
      ..color = skullColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-10, -56), const Offset(18, -48), bones);
    canvas.drawLine(const Offset(-10, -48), const Offset(18, -56), bones);

    // flag on top of the mast (waves a little)
    final f = flutter * 3;
    final flag = Path()
      ..moveTo(4, -106)
      ..quadraticBezierTo(16, -104 + f, 28, -99 + f)
      ..quadraticBezierTo(16, -97 + f, 4, -94)
      ..close();
    canvas.drawPath(flag, fillFlag);
    canvas.drawPath(flag, line..strokeWidth = 1.2);
    line.strokeWidth = 2;

    // hull
    final hull = Path()
      ..moveTo(-50, -12)
      ..lineTo(52, -12)
      ..quadraticBezierTo(42, 14, 22, 17)
      ..lineTo(-26, 17)
      ..quadraticBezierTo(-44, 12, -50, -12)
      ..close();
    canvas.drawPath(hull, fillHull);
    canvas.drawPath(hull, line);

    // raised back deck
    final deck = Path()
      ..moveTo(-50, -12)
      ..lineTo(-50, -20)
      ..lineTo(-30, -20)
      ..lineTo(-30, -12)
      ..close();
    canvas.drawPath(deck, fillHull);
    canvas.drawPath(deck, line);

    // red stripe and portholes
    canvas.drawLine(
      const Offset(-44, -5),
      const Offset(46, -5),
      Paint()
        ..color = flagColor
        ..strokeWidth = 3,
    );
    final porthole = Paint()..color = sailColor;
    for (final x in const [-24.0, -4.0, 16.0]) {
      canvas.drawCircle(Offset(x, 6), 2.6, porthole);
    }
  }

  @override
  bool shouldRepaint(covariant _SeaPainter old) =>
      old.dark != dark || old.anim != anim;
}
