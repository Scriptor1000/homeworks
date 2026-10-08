import 'dart:async';

import 'package:collection/collection.dart';
import 'package:dart_untis_mobile/dart_untis_mobile.dart';
import 'package:flutter/widgets.dart';

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

  final Stream<List<Subject>> _stream;
  late StreamSubscription _streamSubscription;

  final FirestoreSubjects _firestoreSubjectsService; // Firestore service

  SubjectProvider({required FirestoreSubjects firestoreSubjects})
    : _firestoreSubjectsService = firestoreSubjects,
      _stream = firestoreSubjects.streamAllSubjects() {
    _streamSubscription = _stream.listen(_streamListener);
  }

  @override
  dispose() {
    _streamSubscription.cancel();
    super.dispose();
  }

  void _streamListener(List<Subject> subjects) {
    _firestoreSubjects = subjects;
    _firestoreSubjectsLoaded = true;
    notifyListeners();
  }

  /// The list of all subjects, currently only from Firestore
  List<Subject> get subjects => _firestoreSubjects;

  /// The list of Untis subjects
  List<Subject> get untisSubjects => _untisSubjects;

  /// Whether the subjects are loaded from Firestore
  bool get firestoreSubjectsLoaded => _firestoreSubjectsLoaded;

  /// Status of the Untis subjects
  UntisSubjectStatus get untisSubjectStatus => _untisSubjectStatus;

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

  void setUntisSubjects(
    List<Subject>? untisSubjects,
    UntisSubjectStatus status,
  ) {
    _untisSubjects = untisSubjects ?? [];
    _untisSubjectStatus = status;
    notifyListeners();
  }

  void updateNextLessonForSubject(String subjectDocId, DateTime? nextLesson) {
    final subjectIndex = _firestoreSubjects.indexWhere(
      (subject) => subject.documentId == subjectDocId,
    );
    if (subjectIndex != -1) {
      _firestoreSubjects[subjectIndex].nextLesson = nextLesson;
      notifyListeners();
    }
  }

  /// Adds a new subject to Firestore and local list
  Future<void> addSubject(Subject subject) async {
    await _firestoreSubjectsService.saveSubject(subject);
    notifyListeners();
  }

  /// Deletes a subject from Firestore and local list
  Future<void> removeSubject(Subject subject) async {
    await _firestoreSubjectsService.deleteSubject(subject);
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
