import 'package:flutter/material.dart';

import '../database/homeworks.dart';
import '../database/models/homework.dart';
import '../database/models/subject.dart';
import '../utilities/homeworks_list.dart';
import '../utilities/constants.dart';

/// Provider for managing homeworks
///
/// This class handles loading, creating, updating, and deleting homeworks.
/// It interacts with [FirestoreHomeworks] for persistent storage and keeps
/// a local list [_homeworks] in sync.
class HomeworksProvider extends ChangeNotifier {
  List<Homework> _homeworks = []; // local list of homeworks
  bool _homeworksLoaded = false; // whether homeworks have been loaded

  final FirestoreHomeworks _firestoreHomeworks; // Firestore interface

  HomeworksProvider({required FirestoreHomeworks firestoreHomeworks})
      : _firestoreHomeworks = firestoreHomeworks;

  /// The list of homeworks which have a due date
  ///
  /// Returns an unmodifiable list to prevent external modification.
  Homeworks get homeworks =>
      Homeworks(homeworks: List.unmodifiable(_homeworks));

  /// Whether the homeworks have been loaded from Firestore
  bool get homeworksLoaded => _homeworksLoaded;

  /// Initializes the provider by loading homeworks from Firestore
  ///
  /// Should be called at app start to load or refresh homeworks.
  Future<void> initialize() async {
    try {
      await _loadHomeworks();
    } catch (e) {
      print('Error loading Firestore data: $e');
      rethrow;
    }
    notifyListeners();
  }

  /// Loads all homeworks from Firestore and removes old completed ones
  Future<void> _loadHomeworks() async {
    _homeworks = await _firestoreHomeworks.loadAllHomeworks();
    final now = DateTime.now();

    // Delete completed homeworks which are past due date
    // TODO: find better place for this cleanup
    final toDelete = _homeworks
        .where((homework) =>
    homework.dueDate != null &&
        homework.dueDate!.isBefore(now) &&
        homework.isCompleted)
        .toList();
    for (var homework in toDelete) {
      await _firestoreHomeworks.deleteHomework(homework.id);
    }

    // Remove the same homeworks locally
    _homeworks.removeWhere((homework) =>
    homework.dueDate != null &&
        homework.dueDate!.isBefore(now) &&
        homework.isCompleted);

    _homeworksLoaded = true;
    notifyListeners();
  }

  /// Updates the due dates of homeworks based on next lesson dates
  ///
  /// Updates only homeworks which are from Untis, address the next lesson,
  /// and are not already past due.
  Future<void> updateDueDates(
      Map<String, DateTime> nextLessonDates, DateTime scanRange) async {
    final now = DateTime.now();
    for (var homework in _homeworks) {
      // Skip homework not addressed or already past
      if (!homework.toNextLesson ||
          !homework.fromUntis ||
          (homework.dueDate != null && homework.dueDate!.isBefore(now))) {
        continue;
      }

      // No next lesson date but due date is in scan range => clear due date
      if (!nextLessonDates.containsKey(homework.subjectDocId) &&
          homework.dueDate != null &&
          homework.dueDate!.isBefore(scanRange)) {
        homework.dueDate = null;
        _firestoreHomeworks.saveHomework(homework);
      } else
        // If next lesson date differs from current due date => update
      if (nextLessonDates.containsKey(homework.subjectDocId) &&
          nextLessonDates[homework.subjectDocId] != homework.dueDate) {
        homework.dueDate = nextLessonDates[homework.subjectDocId];
        _firestoreHomeworks.saveHomework(homework);
      }
    }
    notifyListeners();
  }

  /// Creates a new homework quickly with a title and subject
  ///
  /// Sets standard values, marks as exam if title starts with examPrefixes,
  /// adds to local list and saves in Firestore.
  Future<void> fastCreateHomework(String title, Subject subject) async {
    final nextLesson = subject.nextLesson;
    bool isExam = false;

    // Check for exam prefixes
    for (final prefix in examPrefixes) {
      if (title.startsWith(prefix)) {
        isExam = true;
        title = title.replaceAll(prefix, '');
        break;
      }
    }

    var homework = Homework(
      title: title,
      description: '',
      subjectDocId: subject.documentId,
      toNextLesson: true,
      isCompleted: false,
      dueDate: nextLesson,
      fromUntis: false,
      isExam: isExam,
    );

    _homeworks.add(homework);
    await _firestoreHomeworks.saveHomework(homework);
    notifyListeners();
  }

  /// Creates a homework from a full [Homework] object
  ///
  /// Adds it to the local list and saves in Firestore.
  Future<void> createHomework(Homework homework) async {
    _homeworks.add(homework);
    await _firestoreHomeworks.saveHomework(homework);
    notifyListeners();
  }

  /// Deletes a homework from Firestore and local list
  ///
  /// Finds the homework by its [homework.id] and removes it.
  Future<void> deleteHomework(Homework homework) async {
    final index = _homeworks.indexWhere((hw) => hw.id == homework.id);
    if (index != -1) {
      await _firestoreHomeworks.deleteHomework(homework.documentId);
      _homeworks.removeAt(index);
      notifyListeners();
    } else {
      print('Homework with id ${homework.id} not found.');
      print('Current homeworks: ${_homeworks.map((hw) => hw.id).join(', ')}');
    }
  }

  /// Updates the due date of an existing homework
  ///
  /// Saves the updated homework in Firestore and notifies listeners.
  Future<void> newDueDate(Homework homework, DateTime dueDate) async {
    final index = _homeworks.indexWhere((hw) => hw.id == homework.id);
    if (index != -1) {
      _homeworks[index].dueDate = dueDate;
      await _firestoreHomeworks.saveHomework(_homeworks[index]);
      notifyListeners();
    } else {
      print('Homework with id ${homework.id} not found.');
      print('Current homeworks: ${_homeworks.map((hw) => hw.id).join(', ')}');
    }
  }

  /// Marks a homework as completed
  ///
  /// Updates the local list and saves the change in Firestore.
  Future<void> completeHomework(Homework homework) async {
    final index = _homeworks.indexWhere((hw) => hw.id == homework.id);
    if (index != -1) {
      _homeworks[index].isCompleted = true;
      await _firestoreHomeworks.saveHomework(_homeworks[index]);
      notifyListeners();
    } else {
      print('Homework with id ${homework.id} not found.');
      print('Current homeworks: ${_homeworks.map((hw) => hw.id).join(', ')}');
    }
  }
}
