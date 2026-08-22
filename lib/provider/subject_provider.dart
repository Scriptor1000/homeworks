import 'package:collection/collection.dart';
import 'package:dart_untis_mobile/dart_untis_mobile.dart';
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

  bool _firestoreSubjectsLoaded =
      false; // whether Firestore subjects are loaded
  UntisSubjectStatus _untisSubjectStatus =
      UntisSubjectStatus.untisUnavailable; // status of Untis subjects

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
    await _loadSubjects();
    notifyListeners();
  }

  /// The subject associated with the given [UntisElementDescriptor].
  ///
  /// Returns null if no such subject exists within [_firestoreSubjects].
  Subject? getSubjectByUntisId(UntisElementDescriptor untisId) {
    if (untisId.type != UntisElementType.subject) {
      return null;
    }
    return _firestoreSubjects.firstWhereOrNull(
      (subject) => subject.id == untisId.id && subject.fromUntis,
    );
  }

  /// Updates Untis subjects based on data from [UntisProvider]
  ///
  /// Updates [_untisSubjects] and [_untisSubjectStatus], and also updates
  /// the next lesson dates in [_firestoreSubjects] if they match.
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

  /// Toggles the visibility flag of a subject in Firestore and [_firestoreSubjects].
  Future<void> toggleSubjectVisibility(String subjectDocId) async {
    final subject = _firestoreSubjects.firstWhereOrNull(
      (subject) => subject.documentId == subjectDocId,
    );
    if (subject == null) return;
    subject.visible = !subject.visible;
    await _firestoreSubjectsService.saveSubject(subject);
    notifyListeners();
  }
}
