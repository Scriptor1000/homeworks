import '../database/models/homework.dart';
import 'dart:collection';

import 'common.dart';

/// A class that represents a list of homeworks.
///
/// This class provides various filters to retrieve specific subsets of homeworks.
/// It extends [ListBase] to provide all methods of a list.
/// Requires a list of [Homework] objects in the contructor, this can be an empty list.
/// Example usage:
/// ```dart
/// final homeworks = Homeworks(homeworks: [/* list of homeworks */]);
/// final urgentHomeworks = homeworks.urgent;
/// final notCompletedUrgent = homeworks.urgent.notCompleted;
/// ```
class Homeworks extends ListBase<Homework> {
  final List<Homework> _homeworks;

  Homeworks({required List<Homework> homeworks}) : _homeworks = homeworks;

  Homeworks get urgent =>
      Homeworks(homeworks: _homeworks.where((h) => h.isUrgent).toList());

  Homeworks get notUrgent =>
      Homeworks(homeworks: _homeworks.where((h) => !h.isUrgent).toList());

  Homeworks get notCompleted =>
      Homeworks(homeworks: _homeworks.where((h) => !h.isCompleted).toList());

  Homeworks get completed =>
      Homeworks(homeworks: _homeworks.where((h) => h.isCompleted).toList());

  Homeworks get withDueDate =>
      Homeworks(homeworks: _homeworks.where((h) => h.dueDate != null).toList());

  Homeworks get withoutDueDate =>
      Homeworks(homeworks: _homeworks.where((h) => h.dueDate == null).toList());

  Homeworks get overdue => Homeworks(
    homeworks: _homeworks
        .where((h) => h.dueDate != null && h.dueDate!.isBefore(DateTime.now()))
        .toList(),
  );

  List<DateTime> get dueDates =>
      _homeworks
          .where((h) => h.dueDate != null)
          .map((h) => normalizeDate(h.dueDate!))
          .toSet()
          .toList()
        ..sort();

  Homeworks getForDate(DateTime date) {
    final normalizedDate = normalizeDate(date);
    return Homeworks(
      homeworks: _homeworks
          .where(
            (h) =>
                h.dueDate != null &&
                normalizeDate(h.dueDate!) == normalizedDate,
          )
          .toList(),
    );
  }

  Homeworks getForAfterDate(DateTime date) {
    final normalizedDate = normalizeDate(date);
    return Homeworks(
      homeworks: _homeworks
          .where(
            (h) =>
                h.dueDate != null &&
                normalizeDate(h.dueDate!).isAfter(normalizedDate),
          )
          .toList(),
    );
  }

  // These 4 have to be implemented for ListBase, all other methods are based on them.
  @override
  int get length => _homeworks.length;

  @override
  set length(int newLength) => _homeworks.length = newLength;

  @override
  Homework operator [](int index) => _homeworks[index];

  @override
  void operator []=(int index, Homework value) => _homeworks[index] = value;
}
