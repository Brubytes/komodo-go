import 'package:flutter/material.dart';

class SparklineChart extends StatelessWidget {
  const SparklineChart({
    required this.values,
    required this.color,
    super.key,
    this.capMinY,
    this.capMaxY,
  });

  final List<double> values;
  final Color color;
  final double? capMinY;
  final double? capMaxY;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _SparklinePainter(
        values: values,
        color: color,
        gridColor: scheme.outlineVariant.withValues(alpha: 0.6),
        capMinY: capMinY,
        capMaxY: capMaxY,
      ),
    );
  }
}

class DualSparklineChart extends StatelessWidget {
  const DualSparklineChart({
    required this.aValues,
    required this.bValues,
    required this.aColor,
    required this.bColor,
    super.key,
  });

  final List<double> aValues;
  final List<double> bValues;
  final Color aColor;
  final Color bColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _DualSparklinePainter(
        aValues: aValues,
        bValues: bValues,
        aColor: aColor,
        bColor: bColor,
        gridColor: scheme.outlineVariant.withValues(alpha: 0.6),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.color,
    required this.gridColor,
    this.capMinY,
    this.capMaxY,
  });

  final List<double> values;
  final Color color;
  final Color gridColor;
  final double? capMinY;
  final double? capMaxY;

  @override
  void paint(Canvas canvas, Size size) {
    const padding = 6.0;
    final rect = Rect.fromLTWH(
      padding,
      padding,
      size.width - padding * 2,
      size.height - padding * 2,
    );

    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final y in [0.0, 0.5, 1.0]) {
      final dy = rect.bottom - rect.height * y;
      canvas.drawLine(Offset(rect.left, dy), Offset(rect.right, dy), gridPaint);
    }

    if (values.length < 2) return;

    final rawMin = values.reduce((a, b) => a < b ? a : b);
    final rawMax = values.reduce((a, b) => a > b ? a : b);
    final range = (rawMax - rawMin).abs();

    var paddedMin = rawMin - (range * 0.12);
    var paddedMax = rawMax + (range * 0.12);
    if ((paddedMax - paddedMin).abs() < 1e-6) {
      paddedMin -= 1;
      paddedMax += 1;
    }

    if (capMinY != null) {
      paddedMin = paddedMin < capMinY! ? capMinY! : paddedMin;
    }
    if (capMaxY != null) {
      paddedMax = paddedMax > capMaxY! ? capMaxY! : paddedMax;
    }

    if (paddedMax - paddedMin < 1e-9) {
      paddedMax = paddedMin + 1;
    }

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final t = i / (values.length - 1);
      final x = rect.left + rect.width * t;
      final normalized = (values[i] - paddedMin) / (paddedMax - paddedMin);
      final y = rect.bottom - rect.height * normalized.clamp(0, 1);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close();

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.color != color ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.capMinY != capMinY ||
        oldDelegate.capMaxY != capMaxY;
  }
}

class _DualSparklinePainter extends CustomPainter {
  _DualSparklinePainter({
    required this.aValues,
    required this.bValues,
    required this.aColor,
    required this.bColor,
    required this.gridColor,
  });

  final List<double> aValues;
  final List<double> bValues;
  final Color aColor;
  final Color bColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    const padding = 6.0;
    final rect = Rect.fromLTWH(
      padding,
      padding,
      size.width - padding * 2,
      size.height - padding * 2,
    );

    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final y in [0.0, 0.5, 1.0]) {
      final dy = rect.bottom - rect.height * y;
      canvas.drawLine(Offset(rect.left, dy), Offset(rect.right, dy), gridPaint);
    }

    if (aValues.length < 2 || bValues.length < 2) return;

    var localMin = aValues.first;
    var localMax = aValues.first;

    for (final v in aValues) {
      if (v < localMin) localMin = v;
      if (v > localMax) localMax = v;
    }
    for (final v in bValues) {
      if (v < localMin) localMin = v;
      if (v > localMax) localMax = v;
    }
    if (localMax - localMin < 1e-9) {
      localMax = localMin + 1;
    }

    void drawLine(List<double> values, Color color) {
      final path = Path();
      for (var i = 0; i < values.length; i++) {
        final t = i / (values.length - 1);
        final x = rect.left + rect.width * t;
        final normalized = (values[i] - localMin) / (localMax - localMin);
        final y = rect.bottom - rect.height * normalized.clamp(0, 1);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      final linePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, linePaint);
    }

    drawLine(aValues, aColor);
    drawLine(bValues, bColor);
  }

  @override
  bool shouldRepaint(covariant _DualSparklinePainter oldDelegate) {
    return oldDelegate.aValues != aValues ||
        oldDelegate.bValues != bValues ||
        oldDelegate.aColor != aColor ||
        oldDelegate.bColor != bColor ||
        oldDelegate.gridColor != gridColor;
  }
}
