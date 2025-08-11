import 'dart:core';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

/// A Homework wich can be saved to Firestore.
class Homework {
  final String id;
  final String title;
  final String description;
  final String subjectDocId;
  final bool toNextLesson;
  final bool isExam;
  final bool fromUntis;
  final DateTime createdAt;
  bool isCompleted;

  // dueDate can be null, but only if toNextLesson is true wich can only be if the subject is from Untis.
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
    if (toNextLesson) {
      assert(
        subjectDocId.startsWith("untis"),
        'Homework with toNextLesson must be assoziated with a Subject from Untis.',
      );
    }
    if (dueDate == null) {
      assert(
        toNextLesson,
        'Homework with no dueDate must be toNextLesson so a dueDate can be found.',
      );
    }
  }

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

  String get documentId => fromUntis ? 'imported_$id' : id;

  /// Checks if the homework is due today or earlier.
  /// If the homework is an exam, it is urgent if it is due in the next 3 days.
  bool get isUrgent =>
      dueDate != null &&
      DateTime(dueDate!.year, dueDate!.month, dueDate!.day)
              .difference(DateTime.now())
              .inDays <
          (isExam ? 3 : 1);
}
