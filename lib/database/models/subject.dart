import 'dart:ui';

import 'package:dart_untis_mobile/dart_untis_mobile.dart';

/// A Subject wich can be imported from Untis or created manually.
class Subject {
  final Color backColor;
  final Color foreColor;
  final int id;
  final bool fromUntis;
  final String name;
  final String shortName;
  bool visible;
  DateTime? nextLesson;

  Subject.fromUntisSubject(UntisSubject untisSubject)
    : backColor = Color(untisSubject.backColorValue ?? 0),
      foreColor = Color(untisSubject.foreColorValue ?? 0xFFFFFFFF),
      id = untisSubject.id.id,
      name = untisSubject.longName,
      fromUntis = true,
      visible = true,
      shortName = untisSubject.name;

  Subject.fromDocument(Map<String, dynamic> doc)
    : backColor = Color(doc['backColor'] ?? 0),
      foreColor = Color(doc['foreColor'] ?? 0xFFFFFFFF),
      id = doc['id'] ?? -1,
      fromUntis = doc['fromUntis'] ?? false,
      name = doc['name'] ?? '<Kein Name gespeichert>',
      shortName = doc['shortName'] ?? '<0>',
      visible = doc['visible'] ?? true;

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

  String get documentId => fromUntis ? 'untis_$id' : 'custom_$id';
}
