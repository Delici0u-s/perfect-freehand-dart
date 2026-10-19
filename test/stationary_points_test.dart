import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:perfect_freehand/src/get_stroke_radius.dart';

/// A stylus tapped without moving often reports several points
/// at the same position, each with a different pressure.
List<PointVector> stationaryPoints(List<double?> pressures) => [
      for (final pressure in pressures) PointVector(100, 100, pressure),
    ];

void main() {
  group('stationary points', () {
    const pressureSets = {
      'two pressures': [0.736, 0.127],
      'three pressures': [0.615, 0.57, 0.435],
      'four pressures': [0.616, 0.66, 0.672, 0.459],
      'three null pressures': [null, null, null],
    };
    final manyPressures = [for (var i = 0; i < 100; i++) (i % 10) / 10];

    for (final entry in {
      ...pressureSets,
      'many pressures': manyPressures,
    }.entries) {
      for (final simulatePressure in [false, true]) {
        for (final isComplete in [false, true]) {
          test(
              '${entry.key} draw a dot '
              '(simulatePressure: $simulatePressure, isComplete: $isComplete)',
              () {
            final options = StrokeOptions(
              simulatePressure: simulatePressure,
              isComplete: isComplete,
            );
            final outline =
                getStroke(stationaryPoints(entry.value), options: options);

            expect(outline, isNotEmpty);
            expect(outline.every((offset) => offset.isFinite), true,
                reason: 'outline should not contain NaN');

            // Any point's radius is at least the radius at zero pressure.
            // The dot is a polygon inscribed in that circle, so only require
            // one radius across to stay clear of the polygon approximation.
            final minRadius = getStrokeRadius(
              options.size,
              options.thinning,
              0,
              options.easing,
            );
            final bounds = (Path()..addPolygon(outline, true)).getBounds();
            expect(bounds.width, greaterThanOrEqualTo(minRadius),
                reason: 'dot should not collapse to zero width');
            expect(bounds.height, greaterThanOrEqualTo(minRadius),
                reason: 'dot should not collapse to zero height');
          });
        }
      }
    }

    test('are reduced to a single point with the highest pressure', () {
      final options = StrokeOptions(isComplete: true, simulatePressure: false);
      for (final pressures in pressureSets.values) {
        final strokePoints =
            getStrokePoints(stationaryPoints(pressures), options: options);
        final maxPressure = pressures.map((p) => p ?? 0.5).reduce(max);
        expect(strokePoints.first.point.pressure, maxPressure);
      }
    });

    test('the dot size follows the highest pressure, in any order', () {
      final options = StrokeOptions(isComplete: true, simulatePressure: false);
      Size dotSize(List<double> pressures) => (Path()
            ..addPolygon(
              getStroke(stationaryPoints(pressures), options: options),
              true,
            ))
          .getBounds()
          .size;

      final pressedHard = dotSize([0.9]);
      expect(dotSize([0.1, 0.9]), pressedHard);
      expect(dotSize([0.9, 0.1]), pressedHard);
      expect(dotSize([0.2, 0.9, 0.4, 0.1]), pressedHard);
      expect(dotSize([0.1]).width, lessThan(pressedHard.width));
    });

    test('a tap that wobbles slightly still uses the highest pressure', () {
      // A real tap often drifts by a fraction of a pixel between points.
      List<PointVector> wobblingPoints(List<double> pressures) => [
            for (final (i, pressure) in pressures.indexed)
              PointVector(100 + i * 0.05, 100 - i * 0.03, pressure),
          ];

      for (final isComplete in [false, true]) {
        final options =
            StrokeOptions(isComplete: isComplete, simulatePressure: false);
        double dotWidth(List<PointVector> points) =>
            (Path()..addPolygon(getStroke(points, options: options), true))
                .getBounds()
                .width;

        final pressedHard = dotWidth(stationaryPoints([0.9]));
        for (final pressures in [
          [0.9, 0.1],
          [0.2, 0.9, 0.4, 0.1],
          [0.1, 0.5, 0.9],
        ]) {
          expect(dotWidth(wobblingPoints(pressures)),
              closeTo(pressedHard, options.size * 0.1),
              reason: '$pressures (isComplete: $isComplete)');
        }
      }
    });
  });

  group('PointVector.isAtSamePositionAs', () {
    test('ignores pressure', () {
      const a = PointVector(1, 2, 0.1);
      const b = PointVector(1, 2, 0.9);
      expect(a == b, false);
      expect(a.isAtSamePositionAs(b), true);
    });

    test('compares x and y', () {
      const a = PointVector(1, 2, 0.5);
      expect(a.isAtSamePositionAs(const PointVector(1, 3, 0.5)), false);
      expect(a.isAtSamePositionAs(const PointVector(3, 2, 0.5)), false);
      expect(a.isAtSamePositionAs(const Offset(1, 2)), true);
    });
  });
}
