class GoalProjection {
  /// Progress (0.0 to 1.0) of [netWorth] towards [targetValue].
  static double progress(double netWorth, double targetValue) {
    if (targetValue <= 0) return 0;
    final p = netWorth / targetValue;
    if (p.isNaN || p < 0) return 0;
    return p > 1 ? 1 : p;
  }

  /// Whole months needed to reach [targetValue] from [netWorth] by saving
  /// [monthlyContribution] per month. Returns 0 if already reached, null if
  /// the contribution can never get there.
  static int? monthsToReach(double netWorth, double targetValue, double monthlyContribution) {
    final remaining = targetValue - netWorth;
    if (remaining <= 0) return 0;
    if (monthlyContribution <= 0) return null;
    return (remaining / monthlyContribution).ceil();
  }

  /// Monthly contribution required to go from [netWorth] to [targetValue]
  /// by [targetDate]. Returns 0 if already reached, null if [targetDate] is
  /// not in the future relative to [from].
  static double? requiredMonthlyContribution(
    double netWorth,
    double targetValue,
    DateTime targetDate,
    DateTime from,
  ) {
    final remaining = targetValue - netWorth;
    if (remaining <= 0) return 0;
    final months = monthsBetween(from, targetDate);
    if (months <= 0) return null;
    return remaining / months;
  }

  /// Whole months between two dates (fractional days rounded down).
  static int monthsBetween(DateTime from, DateTime to) {
    return (to.year - from.year) * 12 + (to.month - from.month) + (to.day >= from.day ? 0 : -1);
  }
}
