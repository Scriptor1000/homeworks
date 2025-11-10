import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import 'untis_provider.dart';
import '../utilities/enums.dart';
import '../database/subjects.dart';
import '../database/models/subject.dart';

/// Provider for managing subjects
///
/// Handles loading subjects from Firestore, syncing with Untis subjects,
/// and managing their status. Allows adding and removing subjects from Firestore.
class SubjectProvider extends ChangeNotifier {
  List<Subject> _firestoreSubjects = []; // subjects loaded from Firestore
  List<Subject> _untisSubjects = []; // subjects loaded from Untis

  bool _firestoreSubjectsLoaded = false; // whether Firestore subjects are loaded
  UntisSubjectStatus _untisSubjectStatus = UntisSubjectStatus.untisUnavailable; // status of Untis subjects

  final FirestoreSubjects _firestoreSubjectsService; // Firestore service

  SubjectProvider({required FirestoreSubjects firestoreSubjects})
      : _firestoreSubjectsService = firestoreSubjects;

  /// The list of all subjects, currently only from Firestore
  List<Subject> get subjects => _firestoreSubjects;

  /// The list of Untis subjects
  List<Subject> get untisSubjects => _untisSubjects;

  /// Whether the subjects are loaded from Firestore
  bool get firestoreSubjectsLoaded => _firestoreSubjectsLoaded;

  /// Status of the Untis subjects
  UntisSubjectStatus get untisSubjectStatus => _untisSubjectStatus;

  /// Initializes the provider by loading subjects from Firestore
  ///
  /// Should be called at app start to load or refresh subjects.
  Future<void> initialize() async {
    try {
      await _loadSubjects();
    } catch (e) {
      print('Error loading Firestore data: $e');
      rethrow;
    }
    notifyListeners();
  }

  /// Updates Untis subjects based on data from [UntisProvider]
  ///
  /// Updates [_untisSubjects] and [_untisSubjectStatus], and also updates
  /// the next lesson dates in [_firestoreSubjects] if they match.
  void updateUntisSubjects(UntisProvider untisProvider) {
    if (!untisProvider.untisSubjectsLoaded) {
      _untisSubjects = [];
      _untisSubjectStatus = untisProvider.untisSubjectStatus;
      return;
    }

    _untisSubjects = untisProvider.untisSubjects;
    _untisSubjectStatus = UntisSubjectStatus.loaded;

    // Sync next lesson dates from Untis to Firestore subjects
    for (var untisSubject in _untisSubjects) {
      final existingSubject = _firestoreSubjects.firstWhereOrNull(
            (subject) => subject.documentId == untisSubject.documentId,
      );
      if (existingSubject != null) {
        existingSubject.nextLesson = untisSubject.nextLesson;
      }
    }

    notifyListeners();
  }

  /// Loads all subjects from Firestore
  Future<void> _loadSubjects() async {
    _firestoreSubjects = await _firestoreSubjectsService.loadAllUntisSubjects();
    _firestoreSubjectsLoaded = true;
    notifyListeners();
  }

  /// Adds a new subject to Firestore and local list
  Future<void> addSubject(Subject subject) async {
    await _firestoreSubjectsService.saveSubject(subject);
    _firestoreSubjects.add(subject);
    notifyListeners();
  }

  /// Deletes a subject from Firestore and local list
  Future<void> removeSubject(Subject subject) async {
    await _firestoreSubjectsService.deleteSubject(subject);
    _firestoreSubjects.removeWhere((s) => s.id == subject.id);
    notifyListeners();
  }
}
