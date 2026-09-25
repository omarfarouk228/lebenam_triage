import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import 'logo_paths.dart';

typedef _Line = (num, num, num, num);

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

String _svg(String viewBox, String body) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="$viewBox">$body</svg>';

String _paths(Iterable<String> ds, Color fill) =>
    ds.map((d) => '<path fill="${_hex(fill)}" d="$d"/>').join();

String _lines(Iterable<_Line> lines, Color stroke, double width) => lines
    .map(
      (l) =>
          '<line x1="${l.$1}" y1="${l.$2}" x2="${l.$3}" y2="${l.$4}" '
          'stroke="${_hex(stroke)}" stroke-width="$width" '
          'stroke-miterlimit="10"/>',
    )
    .join();

/// Brand colours for the current background: the official "on white"
/// version in light mode, the "on blue" one (white letters) in dark mode.
({Color ink, Color accent}) _colors(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? (ink: AppColors.cream, accent: AppColors.brandOrange)
    : (ink: AppColors.brand, accent: AppColors.brandOrange);

/// The stacked Lébénam logo ("Lébé" over "nam", with the wave).
///
/// With [progress] (0 → 1) it draws itself: "Lébé" rises, "nam" follows,
/// the accents drop in and the wave sweeps from left to right.
class LebenamLogo extends StatelessWidget {
  const LebenamLogo({super.key, this.width = 160, this.progress});

  final double width;
  final Animation<double>? progress;

  static const _aspect = 440.43 / 360.73;

  @override
  Widget build(BuildContext context) {
    final c = _colors(context);
    final lebe = _svg(logoViewBox, _paths(logoLebePaths, c.ink));
    final nam = _svg(logoViewBox, _paths(logoNamPaths, c.accent));
    final accents = _svg(
      logoViewBox,
      _lines(logoAccentLines, c.accent, logoAccentStrokeWidth),
    );
    final wave = _svg(logoViewBox, _paths(logoWavePaths, c.ink));

    Widget layer(String svg) => SvgPicture.string(
      svg,
      width: width,
      height: width / _aspect,
      excludeFromSemantics: true,
    );

    final p = progress;
    return Semantics(
      label: 'Lébénam',
      image: true,
      child: SizedBox(
        width: width,
        height: width / _aspect,
        child: Stack(
          children: p == null
              ? [layer(lebe), layer(accents), layer(nam), layer(wave)]
              : [
                  _Rise(progress: p, start: 0, end: 0.4, child: layer(lebe)),
                  _Rise(progress: p, start: 0.15, end: 0.55, child: layer(nam)),
                  _Rise(
                    progress: p,
                    start: 0.4,
                    end: 0.7,
                    offset: -0.06,
                    child: layer(accents),
                  ),
                  _Wipe(progress: p, start: 0.5, end: 1, child: layer(wave)),
                ],
        ),
      ),
    );
  }
}

/// The horizontal Lébénam wordmark, for app bars and headers.
class LebenamWordmark extends StatelessWidget {
  const LebenamWordmark({super.key, this.height = 22});

  final double height;

  static const _aspect = 699.06 / 171.68;

  @override
  Widget build(BuildContext context) {
    final c = _colors(context);
    final body = StringBuffer()
      ..write(
        wordmarkPaths
            .map((p) => _paths([p.$2], p.$1 ? c.accent : c.ink))
            .join(),
      )
      ..write(_lines(wordmarkAccentLines, c.accent, wordmarkAccentStrokeWidth));
    return Semantics(
      label: 'Lébénam',
      image: true,
      child: SvgPicture.string(
        _svg(wordmarkViewBox, body.toString()),
        height: height,
        width: height * _aspect,
        excludeFromSemantics: true,
      ),
    );
  }
}

/// Fades a layer in while sliding it into place.
class _Rise extends StatelessWidget {
  const _Rise({
    required this.progress,
    required this.start,
    required this.end,
    required this.child,
    this.offset = 0.08,
  });

  final Animation<double> progress;
  final double start;
  final double end;
  final double offset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = CurvedAnimation(
      parent: progress,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: t,
      child: SlideTransition(
        position: Tween(begin: Offset(0, offset), end: Offset.zero).animate(t),
        child: child,
      ),
    );
  }
}

/// Reveals a layer from left to right, like a brush stroke.
class _Wipe extends StatelessWidget {
  const _Wipe({
    required this.progress,
    required this.start,
    required this.end,
    required this.child,
  });

  final Animation<double> progress;
  final double start;
  final double end;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = CurvedAnimation(
      parent: progress,
      curve: Interval(start, end, curve: Curves.easeInOutCubic),
    );
    return AnimatedBuilder(
      animation: t,
      builder: (context, child) =>
          ClipRect(clipper: _WipeClipper(t.value), child: child),
      child: child,
    );
  }
}

class _WipeClipper extends CustomClipper<Rect> {
  const _WipeClipper(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_WipeClipper old) => old.fraction != fraction;
}
