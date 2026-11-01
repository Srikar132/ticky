/// Base type for expected, user-facing data layer failures.
abstract class DataException implements Exception {
  const DataException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The routine field a validation error belongs to, so a form can show the
/// message next to the right input.
enum RoutineField { title, reminder, repeatDays, duration, snooze, category }

/// A routine draft broke a domain rule (empty title, alarm without time...).
class InvalidRoutineException extends DataException {
  const InvalidRoutineException(super.message, {this.field});

  /// Null when the problem is not tied to one input.
  final RoutineField? field;
}

/// A category draft broke a domain rule, or the action is not allowed (for
/// example archiving the General category).
class InvalidCategoryException extends DataException {
  const InvalidCategoryException(super.message);
}

/// The requested row does not exist (or is archived).
class NotFoundException extends DataException {
  const NotFoundException(super.message);
}

/// Only today's records can be changed.
class ReadOnlyDayException extends DataException {
  const ReadOnlyDayException(super.message);
}

/// The record is in a state that does not allow the action (e.g. snoozing a
/// task that is already completed).
class InvalidRecordStateException extends DataException {
  const InvalidRecordStateException(super.message);
}

/// The coin balance does not cover the price.
class InsufficientCoinsException extends DataException {
  const InsufficientCoinsException(super.message);
}

/// The item was already bought.
class ItemAlreadyUnlockedException extends DataException {
  const ItemAlreadyUnlockedException(super.message);
}

/// The item cannot be used because it has not been bought.
class ItemNotOwnedException extends DataException {
  const ItemNotOwnedException(super.message);
}
