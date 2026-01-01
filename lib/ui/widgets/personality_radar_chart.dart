import 'dart:math';
import 'dart:ui'; // For lerpDouble
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum RadarMode {
  sculpting, // God Mode: Drag to edit
  monitoring, // Observer Mode: Read only
}

class PersonalityRadarChart extends StatefulWidget {
  final Map<String, double> initialTraits; // Factory settings (Dashed)
  final Map<String, double>? effectiveTraits; // Current persona (Solid) - Optional
  final RadarMode mode;
  final ValueChanged<Map<String, double>>? onTraitChanged;
  final bool isDark;

  const PersonalityRadarChart({
    super.key,
    required this.initialTraits,
    this.effectiveTraits,
    this.mode = RadarMode.monitoring,
    this.onTraitChanged,
    required this.isDark,
  });

  @override
  State<PersonalityRadarChart> createState() => _PersonalityRadarChartState();
}

class _PersonalityRadarChartState extends State<PersonalityRadarChart> with SingleTickerProviderStateMixin {
  // Order: O, C, E, A, N
  static const List<String> _keys = [
    'openness',
    'conscientiousness',
    'extraversion',
    'agreeableness',
    'neuroticism'
  ];
  
  static const List<String> _labels = ['开放', '尽责', '外向', '宜人', '敏感'];

  late Map<String, double> _currentTraits;
  late AnimationController _controller;
  Map<String, double>? _prevTraits;
  
  // Drag state
  int? _dragIndex;
  double? _lastHapticValue;

  @override
  void initState() {
    super.initState();
    _currentTraits = Map.from(widget.initialTraits);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details, Size size, double radius, Offset center) {
    if (widget.mode != RadarMode.sculpting) return;

    final touchPoint = details.localPosition;
    
    // Find nearest vertex
    int? nearestIndex;
    double minDistance = 40.0; // Hit test radius

    final angle = 2 * pi / 5;

    for (int i = 0; i < 5; i++) {
      final key = _keys[i];
      final value = _currentTraits[key] ?? 0.5;
      final r = radius * value;
      // Vertex position
      final vx = center.dx + r * cos(angle * i - pi / 2);
      final vy = center.dy + r * sin(angle * i - pi / 2);
      
      final d = (touchPoint - Offset(vx, vy)).distance;
      if (d < minDistance) {
        minDistance = d;
        nearestIndex = i;
      }
    }

    setState(() {
      _dragIndex = nearestIndex;
      _lastHapticValue = nearestIndex != null ? _currentTraits[_keys[nearestIndex]] : null;
    });
  }

  void _onPanUpdate(DragUpdateDetails details, Size size, double radius, Offset center) {
    if (_dragIndex == null || widget.mode != RadarMode.sculpting) return;

    final touchPoint = details.localPosition;
    final angle = 2 * pi / 5;
    final vertexAngle = angle * _dragIndex! - pi / 2;

    // Vector from center to touch point
    final dx = touchPoint.dx - center.dx;
    final dy = touchPoint.dy - center.dy;
    
    // Project touch point onto the vertex ray
    // Distance = dot product with unit vector of ray
    final unitX = cos(vertexAngle);
    final unitY = sin(vertexAngle);
    
    double projectedDist = dx * unitX + dy * unitY;
    
    // Normalize to 0.0 - 1.0
    double newValue = (projectedDist / radius).clamp(0.1, 1.0);

    // Haptic feedback check
    if (_lastHapticValue != null && (newValue - _lastHapticValue!).abs() > 0.1) {
      HapticFeedback.selectionClick();
      _lastHapticValue = newValue;
    }

    setState(() {
      _currentTraits[_keys[_dragIndex!]] = newValue;
    });

    widget.onTraitChanged?.call(_currentTraits);
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _dragIndex = null;
      _lastHapticValue = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final center = Offset(size.width / 2, size.height / 2);
        final radius = min(size.width, size.height) / 2 - 20;

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // Interpolation logic
            List<double> initialList = _mapToList(widget.initialTraits);
            List<double> effectiveList;
            
            if (widget.mode == RadarMode.monitoring) {
               // Animate effective traits
               if (_controller.isAnimating && _prevTraits != null) {
                 final oldList = _mapToList(_prevTraits);
                 final newList = _mapToList(widget.effectiveTraits);
                 effectiveList = List.generate(5, (i) {
                   return lerpDouble(oldList[i], newList[i], _controller.value) ?? newList[i];
                 });
               } else {
                 effectiveList = _mapToList(widget.effectiveTraits);
               }
            } else {
              // Sculpting mode: effective traits not shown or same as current
              effectiveList = List.filled(5, 0.0);
            }

            return GestureDetector(
              onPanStart: (d) => _onPanStart(d, size, radius, center),
              onPanUpdate: (d) => _onPanUpdate(d, size, radius, center),
              onPanEnd: _onPanEnd,
              child: CustomPaint(
                size: size,
                painter: _RadarPainter(
                  initialValues: initialList,
                  effectiveValues: effectiveList,
                  currentValuesForSculpting: widget.mode == RadarMode.sculpting 
                      ? _mapToList(_currentTraits) 
                      : null,
                  labels: _labels,
                  isDark: widget.isDark,
                  mode: widget.mode,
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void didUpdateWidget(PersonalityRadarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mode == RadarMode.monitoring) {
      if (oldWidget.effectiveTraits != widget.effectiveTraits) {
        _prevTraits = oldWidget.effectiveTraits;
        _controller.forward(from: 0.0);
      }
    }
  }

  List<double> _mapToList(Map<String, double>? traits) {
    if (traits == null) return List.filled(5, 0.5);
    return _keys.map((k) => traits[k] ?? 0.5).toList();
  }
}

class _RadarPainter extends CustomPainter {
  final List<double> initialValues; // Dashed
  final List<double> effectiveValues; // Solid
  final List<double>? currentValuesForSculpting; // Used if sculpting
  final List<String> labels;
  final bool isDark;
  final RadarMode mode;

  _RadarPainter({
    required this.initialValues,
    required this.effectiveValues,
    this.currentValuesForSculpting,
    required this.labels,
    required this.isDark,
    required this.mode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 20;
    final sides = 5;
    final angle = 2 * pi / sides;

    // Colors
    final gridColor = isDark ? const Color(0xFFFFB74D).withValues(alpha: 0.2) : const Color(0xFF8D6E63).withValues(alpha: 0.2);
    final initialLineColor = isDark ? Colors.white38 : Colors.black26;
    final effectiveFillColor = const Color(0xFFFFB74D).withValues(alpha: 0.3);
    final effectiveStrokeColor = const Color(0xFFFFB74D);
    final sculptColor = const Color(0xFF42A5F5); // Blue for sculpting

    // 1. Draw Grid (3 levels)
    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var level = 1; level <= 3; level++) {
      final levelRadius = radius * level / 3;
      final path = Path();
      for (var i = 0; i < sides; i++) {
        final x = center.dx + levelRadius * cos(angle * i - pi / 2);
        final y = center.dy + levelRadius * sin(angle * i - pi / 2);
        if (i == 0) path.moveTo(x, y);
        else path.lineTo(x, y);
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }
    
    // Axis lines
    for (var i = 0; i < sides; i++) {
       final x = center.dx + radius * cos(angle * i - pi / 2);
       final y = center.dy + radius * sin(angle * i - pi / 2);
       canvas.drawLine(center, Offset(x, y), gridPaint);
    }

    // 2. Draw Data
    if (mode == RadarMode.monitoring) {
      // Layer 1: Initial (Factory Setting) - Dashed Line
      _drawPolygon(canvas, center, radius, initialValues, initialLineColor, isDashed: true);
      
      // Layer 2: Effective (Current) - Solid Fill
      _drawPolygon(canvas, center, radius, effectiveValues, effectiveStrokeColor, fillColor: effectiveFillColor);
    } else {
      // Sculpting Mode
      // We draw the current traits being edited
      final values = currentValuesForSculpting ?? initialValues;
      _drawPolygon(canvas, center, radius, values, sculptColor, fillColor: sculptColor.withValues(alpha: 0.15));
      
      // Draw Handles
      final handlePaint = Paint()..color = sculptColor..style = PaintingStyle.fill;
      for (var i = 0; i < sides; i++) {
        final r = radius * values[i];
        final x = center.dx + r * cos(angle * i - pi / 2);
        final y = center.dy + r * sin(angle * i - pi / 2);
        canvas.drawCircle(Offset(x, y), 8, handlePaint); // Larger touch target visual
        canvas.drawCircle(Offset(x, y), 12, Paint()..color = sculptColor.withValues(alpha: 0.3)); // Glow
      }
    }

    // 3. Labels
    final textStyle = TextStyle(
       color: isDark ? Colors.white60 : Colors.black54,
       fontSize: 12,
    );
    for (var i = 0; i < sides; i++) {
       final labelRadius = radius + 20;
       final x = center.dx + labelRadius * cos(angle * i - pi / 2);
       final y = center.dy + labelRadius * sin(angle * i - pi / 2);
       final span = TextSpan(text: labels[i], style: textStyle);
       final tp = TextPainter(text: span, textDirection: TextDirection.ltr);
       tp.layout();
       tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
    }
  }

  void _drawPolygon(Canvas canvas, Offset center, double radius, List<double> values, Color color, {Color? fillColor, bool isDashed = false}) {
    final path = Path();
    final angle = 2 * pi / 5;

    for (var i = 0; i < 5; i++) {
      final r = radius * values[i].clamp(0.0, 1.0);
      final x = center.dx + r * cos(angle * i - pi / 2);
      final y = center.dy + r * sin(angle * i - pi / 2);
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    path.close();

    if (fillColor != null) {
      canvas.drawPath(path, Paint()..color = fillColor..style = PaintingStyle.fill);
    }

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    if (isDashed) {
      // Simple dashed effect
      final dashPath = Path();
      double distance = 0.0;
      for (PathMetric measurePath in path.computeMetrics()) {
        while (distance < measurePath.length) {
          dashPath.addPath(
            measurePath.extractPath(distance, distance + 5),
            Offset.zero,
          );
          distance += 10;
        }
      }
      canvas.drawPath(dashPath, strokePaint);
    } else {
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return true; // Simplified for animation
  }
}
