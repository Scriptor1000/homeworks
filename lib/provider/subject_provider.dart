import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import 'untis_provider.dart';
import '../utilities/enums.dart';
import '../database/subjects.dart';
import '../database/models/subject.dart';

class SubjectProvider extends ChangeNotifier {
  List<Subject> _firestoreSubjects = [];
  List<Subject> _untisSubjects = [];

  bool _firestoreSubjectsLoaded = false;
  UntisSubjectStatus _untisSubjectStatus = UntisSubjectStatus.untisUnavailable;

  final FirestoreSubjects _firestoreSubjectsService;

  SubjectProvider({required FirestoreSubjects firestoreSubjects})
    : _firestoreSubjectsService = firestoreSubjects;

  /// The list of all subjects, currently only from Untis.
  List<Subject> get subjects => _firestoreSubjects;

  /// The list of Untis subjects.
  List<Subject> get untisSubjects => _untisSubjects;

  /// Wheter the subjects are loaded from Firestore.
  bool get firestoreSubjectsLoaded => _firestoreSubjectsLoaded;

  UntisSubjectStatus get untisSubjectStatus => _untisSubjectStatus;

  /// Initializes the provider by loading subjects and homeworks from Firestore.
  ///
  /// This method should be called at the start of the application to ensure data is loaded or
  /// to refresh the data.
  Future<void> initialize() async {
    await _loadSubjects();
    notifyListeners();
  }

  void updateUntisSubjects(UntisProvider untisProvider) {
    if (!untisProvider.untisSubjectsLoaded) {
      _untisSubjects = [];
      _untisSubjectStatus = untisProvider.untisSubjectStatus;
      notifyListeners();
      return;
    }
    _untisSubjects = untisProvider.untisSubjects;
    _untisSubjectStatus = UntisSubjectStatus.loaded;

    // Update next lesson dates in Firestore subjects
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

  Future<void> _loadSubjects() async {
    _firestoreSubjects = await _firestoreSubjectsService.loadAllUntisSubjects();
    _firestoreSubjectsLoaded = true;
    notifyListeners();
  }

  /// Adds a new subject to Firestore and [_firestoreSubjects].
  Future<void> addSubject(Subject subject) async {
    await _firestoreSubjectsService.saveSubject(subject);
    _firestoreSubjects.add(subject);
    notifyListeners();
  }

  /// Deletes a subject from Firestore and [_firestoreSubjects].
  Future<void> removeSubject(Subject subject) async {
    await _firestoreSubjectsService.deleteSubject(subject);
    _firestoreSubjects.removeWhere((s) => s.id == subject.id);
    notifyListeners();
  }
}
