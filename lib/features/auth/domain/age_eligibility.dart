bool isAtLeast18(DateTime dateOfBirth, {DateTime? today}) {
  final currentDate = today ?? DateTime.now();
  final ageAtYearDifference = currentDate.year - dateOfBirth.year;
  if (ageAtYearDifference > 18) return true;
  if (ageAtYearDifference < 18) return false;
  if (dateOfBirth.month < currentDate.month) return true;
  if (dateOfBirth.month > currentDate.month) return false;
  return dateOfBirth.day <= currentDate.day;
}

DateTime latestEligibleDateOfBirth({DateTime? today}) {
  final currentDate = today ?? DateTime.now();
  return DateTime(
    currentDate.year - 18,
    currentDate.month,
    currentDate.day,
  );
}
