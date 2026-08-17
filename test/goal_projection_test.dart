import 'package:flutter_test/flutter_test.dart';
import 'package:cofrenuvem/utils/goal_projection.dart';

void main() {
  group('GoalProjection.progress', () {
    test('computes proportional progress', () {
      expect(GoalProjection.progress(2500, 10000), closeTo(0.25, 0.0001));
    });

    test('clamps at 1.0 when goal is exceeded', () {
      expect(GoalProjection.progress(15000, 10000), 1.0);
    });

    test('clamps at 0.0 for negative net worth', () {
      expect(GoalProjection.progress(-500, 10000), 0.0);
    });

    test('returns 0 for a non-positive target', () {
      expect(GoalProjection.progress(1000, 0), 0.0);
    });
  });

  group('GoalProjection.monthsToReach', () {
    test('rounds up partial months', () {
      expect(GoalProjection.monthsToReach(1000, 10000, 3000), 3);
    });

    test('returns 0 when already reached', () {
      expect(GoalProjection.monthsToReach(12000, 10000, 500), 0);
    });

    test('returns null when contribution cannot make progress', () {
      expect(GoalProjection.monthsToReach(1000, 10000, 0), isNull);
    });
  });

  group('GoalProjection.requiredMonthlyContribution', () {
    test('splits the remaining amount across the months left', () {
      final from = DateTime(2026, 1, 15);
      final to = DateTime(2026, 7, 15);
      expect(GoalProjection.requiredMonthlyContribution(1000, 7000, to, from), closeTo(1000, 0.0001));
    });

    test('returns 0 when already reached', () {
      final from = DateTime(2026, 1, 15);
      final to = DateTime(2026, 7, 15);
      expect(GoalProjection.requiredMonthlyContribution(8000, 7000, to, from), 0);
    });

    test('returns null when the target date is not in the future', () {
      final from = DateTime(2026, 1, 15);
      final to = DateTime(2026, 1, 10);
      expect(GoalProjection.requiredMonthlyContribution(1000, 7000, to, from), isNull);
    });
  });

  group('GoalProjection.monthsBetween', () {
    test('counts full months, ignoring incomplete trailing month', () {
      expect(GoalProjection.monthsBetween(DateTime(2026, 1, 20), DateTime(2026, 3, 10)), 1);
      expect(GoalProjection.monthsBetween(DateTime(2026, 1, 10), DateTime(2026, 3, 20)), 2);
    });
  });
}
