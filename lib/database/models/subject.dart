import 'dart:ui';

import 'package:dart_untis_mobile/dart_untis_mobile.dart';

/// A Subject which can be imported from Untis or created manually.
///
/// Represents a school subject with color coding, ID, and optional next lesson date.
class Subject {
  /// Background color of the subject, used for UI elements.
  final Color backColor;

  /// Foreground color (text/icon) for the subject.
  final Color foreColor;

  /// Unique ID of the subject.
  final int id;

  /// True if the subject was imported from Untis; false if created manually.
  final bool fromUntis;

  /// Full name of the subject.
  final String name;

  /// Short name or abbreviation of the subject.
  final String shortName;

  /// Visibility of the subject.
  bool visible;

  /// Date of the next lesson for this subject, if available.
  DateTime? nextLesson;

  /// Creates a Subject from an UntisSubject instance.
  ///
  /// Colors are converted from Untis values, and the `fromUntis` flag is set to true.
  Subject.fromUntisSubject(UntisSubject untisSubject)
    : backColor = Color(untisSubject.backColorValue ?? 0),
      foreColor = Color(untisSubject.foreColorValue ?? 0xFFFFFFFF),
      id = untisSubject.id.id,
      name = untisSubject.longName,
      fromUntis = true,
      visible = true,
      shortName = untisSubject.name;

  /// Creates a Subject from a Firestore document.
  ///
  /// Provides default values if some fields are missing in the document.
  Subject.fromDocument(Map<String, dynamic> doc)
    : backColor = Color(doc['backColor'] ?? 0),
      foreColor = Color(doc['foreColor'] ?? 0xFFFFFFFF),
      id = doc['id'] ?? -1,
      fromUntis = doc['fromUntis'] ?? false,
      name = doc['name'] ?? '<Kein Name gespeichert>',
      shortName = doc['shortName'] ?? '<0>',
      visible = doc['visible'] ?? true;

  /// Converts the subject into a Firestore-compatible map.
  Map<String, dynamic> toDocument() {
    return {
      'backColor': backColor.toARGB32(),
      'foreColor': foreColor.toARGB32(),
      'id': id,
      'fromUntis': fromUntis,
      'name': name,
      'shortName': shortName,
      'visible': visible,
    };
  }

  /// Returns the Firestore document ID for this subject.
  ///
  /// Uses a prefix to differentiate between Untis-imported and custom subjects.
  String get documentId => fromUntis ? 'untis_$id' : 'custom_$id';
}
