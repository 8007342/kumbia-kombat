class FightDefinition {
  const FightDefinition(
    this.id,
    this.metric,
    this.cleanSeconds,
    this.successesPerTier,
    this.finalChallenges,
    this.resetAfterFailures,
  );
  final String id;
  final String metric;
  final int cleanSeconds;
  final int successesPerTier;
  final int finalChallenges;
  final int resetAfterFailures;
}

const fights = [
  FightDefinition('garden', 'Mojo', 60, 1, 2, 5),
  FightDefinition('bar', 'Swag', 80, 2, 2, 5),
  FightDefinition('cool-crowd', 'Flow', 95, 2, 3, 4),
  FightDefinition('restroom', 'Nerve', 45, 1, 3, 4),
  FightDefinition('vip', 'Presence', 110, 3, 4, 3),
];

enum ChallengeOutcome { retry, advanced, entranceReset, cleared }

/// One call per complete scored response phrase, never per individual tap.
/// The music conductor applies [tier] at the next authored phrase boundary.
class FightProgress {
  FightProgress(this.definition);
  final FightDefinition definition;
  int tier = 0;
  int successesAtTier = 0;
  int consecutiveFailures = 0;
  int fullTierSuccesses = 0;
  int entranceResets = 0;
  bool cleared = false;

  ChallengeOutcome resolve({required bool passed}) {
    if (cleared) return ChallengeOutcome.cleared;
    if (!passed) {
      consecutiveFailures++;
      tier = tier > 0 ? tier - 1 : 0;
      successesAtTier = 0;
      fullTierSuccesses = 0;
      if (consecutiveFailures >= definition.resetAfterFailures) {
        tier = 0;
        consecutiveFailures = 0;
        entranceResets++;
        return ChallengeOutcome.entranceReset;
      }
      return ChallengeOutcome.retry;
    }
    consecutiveFailures = 0;
    if (tier == 4) {
      fullTierSuccesses++;
      if (fullTierSuccesses >= definition.finalChallenges) {
        cleared = true;
        return ChallengeOutcome.cleared;
      }
    } else {
      successesAtTier++;
      if (successesAtTier >= definition.successesPerTier) {
        tier++;
        successesAtTier = 0;
      }
    }
    return ChallengeOutcome.advanced;
  }
}
