import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

class LineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final Color color;
  final bool isRevenue;

  LineChartPainter({
    required this.data,
    required this.color,
    this.isRevenue = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // Margins for labels and padding to prevent cutoff
    const double leftMargin = 35.0; 
    const double rightMargin = 35.0;
    const double bottomMargin = 25.0;
    const double topMargin = 15.0;

    final drawingWidth = size.width - leftMargin - rightMargin;
    final drawingHeight = size.height - bottomMargin - topMargin;

    if (drawingWidth <= 0 || drawingHeight <= 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    // Calculate max value for scaling
    double maxVal = 0;
    for (var item in data) {
      final val = item['count'] ?? 0;
      if (val is num && val.toDouble() > maxVal) {
        maxVal = val.toDouble();
      }
    }
    
    // Avoid division by zero and add headroom
    if (maxVal == 0) maxVal = 1; 
    maxVal = maxVal * 1.2;

    double xStep = drawingWidth / (data.length - 1 > 0 ? data.length - 1 : 1);

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final val = (item['count'] ?? 0);
      final double y = topMargin + drawingHeight - (val / maxVal * drawingHeight);
      final double x = leftMargin + (i * xStep);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, topMargin + drawingHeight);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    if (data.length > 0) {
      fillPath.lineTo(leftMargin + (data.length - 1) * xStep, topMargin + drawingHeight);
      fillPath.close();
      canvas.drawPath(fillPath, fillPaint);
      canvas.drawPath(path, paint);
    }
    
    // Draw dots and date labels
    final dotPaint = Paint()..color = color;
    final whitePaint = Paint()..color = Colors.white;
    final textStyle = TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.w500);
    
    for (int i = 0; i < data.length; i++) {
        final item = data[i];
        final val = (item['count'] ?? 0);
        final double y = topMargin + drawingHeight - (val / maxVal * drawingHeight);
        final double x = leftMargin + (i * xStep);
        
        canvas.drawCircle(Offset(x,y), 5, whitePaint);
        canvas.drawCircle(Offset(x,y), 3, dotPaint);

        // Draw date labels for key points to avoid overlap
        bool shouldShowLabel = false;
        if (data.length <= 7) {
          shouldShowLabel = true; // Show all if few data points
        } else {
          // Show first, last, and every Nth point
          int interval = (data.length / 5).ceil();
          if (i == 0 || i == data.length - 1 || i % interval == 0) {
            shouldShowLabel = true;
          }
        }

        if (shouldShowLabel) {
          final date = item['date'] as DateTime;
          final dateStr = DateFormat('M/d').format(date);
          _drawText(canvas, dateStr, Offset(x, topMargin + drawingHeight + 8), textStyle);
        }
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();
    
    // Center horizontally
    textPainter.paint(canvas, Offset(offset.dx - (textPainter.width / 2), offset.dy));
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.color != color;
  }
}
