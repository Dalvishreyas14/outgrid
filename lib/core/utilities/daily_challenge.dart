/// Deterministically maps a calendar date to one of the 500 bundled
/// levels, so every player sees the same Daily Challenge on the same
/// day with no network call. Pure function of the date — easy to test
/// and trivially reproducible.
int dailyChallengeGlobalIndex(DateTime date) {
  final key = date.year * 10000 + date.month * 100 + date.day;
  final hash = (key * 2654435761) & 0x7fffffff; // Knuth multiplicative hash
  return (hash % 500) + 1;
}
