import 'package:collection/collection.dart';
import 'package:dart_untis_mobile/dart_untis_mobile.dart';
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

  /// The Subject associated with the given [UntisElementDescriptor].
  ///
  /// Returns null if no such Subject exists within [_firestoreSubjects].
  Subject? getSubjectByUntisId(UntisElementDescriptor untisId) {
    if (untisId.type != UntisElementType.subject) {
      return null;
    }
    return _firestoreSubjects.firstWhereOrNull(
      (subject) => subject.id == untisId.id && subject.fromUntis,
    );
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
      final existingSubject = _firestoreSubjects.indexWhere(
        // (subject) => subject.documentId == untisSubject.documentId,
        (subject) => subject.id == untisSubject.id && subject.fromUntis,
      );
      if (existingSubject != -1) {
        _firestoreSubjects[existingSubject].nextLesson =
            untisSubject.nextLesson;
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

  /// Toggles the visibility flag of a subject in Firestore and [_firestoreSubjects]..
  Future<void> toggleSubjectVisibility(String subjectDocId) async {
    final subject = _firestoreSubjects
        .firstWhereOrNull((subject) => subject.documentId == subjectDocId);
    if (subject == null) return;
    subject.visible = !subject.visible;
    await _firestoreSubjectsService.saveSubject(subject);
    notifyListeners();
  }
}
