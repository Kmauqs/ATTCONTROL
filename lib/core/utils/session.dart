const kSessionTtl = Duration(days: 7);

bool sessionStillValid(DateTime loggedAt, DateTime now) {
  final age = now.difference(loggedAt);
  return !age.isNegative && age < kSessionTtl;
}
