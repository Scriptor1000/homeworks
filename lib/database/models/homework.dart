import 'dart:core';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

/// A Homework which can be saved to Firestore.
///
/// Represents a single homework item with properties like title, description,
/// due date, and associations to a subject. Can be created manually or imported
/// from Untis.
class Homework {
  /// Unique identifier for the homework. Generated automatically if not provided.
   String id;

  /// Title of the homework.
   String title;

  /// Detailed description of the homework.
   String description;

  /// Document ID of the subject this homework belongs to.
   String subjectDocId;

  /// If true, the due date is determined by the next lesson of the subject.
   bool toNextLesson;

  /// Marks if the homework is an exam.
   bool isExam;

  /// Indicates if the homework was imported from Untis.
   bool fromUntis;

  /// Timestamp when the homework was created.
   DateTime createdAt;

  /// Indicates if the homework has been completed.
  bool isCompleted;

  /// The due date for the homework. Can be null if [toNextLesson] is true.
  DateTime? dueDate;

  Homework({
    String? id,
    required this.title,
    required this.description,
    required this.subjectDocId,
    required this.toNextLesson,
    required this.isCompleted,
    required this.fromUntis,
    this.dueDate,
    this.isExam = false, // TODO remove --> own Exam class
    DateTime? createdAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        id = id ?? const Uuid().v4() {
    // Validation: if toNextLesson is true, the subject must be from Untis
    if (toNextLesson) {
      assert(
      subjectDocId.startsWith("untis"),
      'Homework with toNextLesson must be associated with a Subject from Untis.',
      );
    }
    // Validation: if dueDate is null, toNextLesson must be true
    if (dueDate == null) {
      assert(
      toNextLesson,
      'Homework with no dueDate must be toNextLesson so a dueDate can be found.',
      );
    }
  }

  /// Factory constructor to create a [Homework] from a Firestore document.
  factory Homework.fromDocument(Map<String, dynamic> json) {
    return Homework(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      subjectDocId: json['subjectDocId'] as String,
      toNextLesson: json['toNextLesson'] as bool,
      isCompleted: json['isCompleted'] as bool,
      isExam: json['isExam'] as bool? ?? false,
      fromUntis: json['fromUntis'] as bool,
      dueDate: json.containsKey('dueDate')
          ? (json['dueDate'] as Timestamp).toDate()
          : null,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  /// Converts the homework into a Firestore-compatible map.
  Map<String, dynamic> toDocument() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'toNextLesson': toNextLesson,
      'isCompleted': isCompleted,
      'fromUntis': fromUntis,
      'isExam': isExam,
      'subjectDocId': subjectDocId,
      if (dueDate != null) 'dueDate': Timestamp.fromDate(dueDate!),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Returns the Firestore document ID, prefixed if imported from Untis.
  String get documentId => fromUntis ? 'imported_$id' : id;

  /// Checks if the homework is urgent.
  ///
  /// A homework is considered urgent if it is due today or earlier.
  /// Exams are considered urgent if due within the next 3 days.
  bool get isUrgent =>
      dueDate != null &&
          DateTime(dueDate!.year, dueDate!.month, dueDate!.day)
              .difference(DateTime.now())
              .inDays <
              (isExam ? 3 : 1);
}
