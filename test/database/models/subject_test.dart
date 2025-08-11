import 'package:flutter_test/flutter_test.dart';
import 'package:homeworks/database/models/subject.dart';

void main() {
  group('Subject Model Tests', () {
    test('subjects should be identical when stored and read from database', () {
      // setup
      final original = subjectWithFalseData(fromUntis: false, id: 7);
      // test
      final document = original.toDocument();
      final loaded = Subject.fromDocument(document);
      // verify
      expect(loaded.id, original.id);
      expect(loaded.name, original.name);
      expect(loaded.shortName, original.shortName);
      expect(loaded.fromUntis, original.fromUntis);
      expect(loaded.backColor, original.backColor);
      expect(loaded.foreColor, original.foreColor);
      expect(loaded.documentId, 'custom_${original.id}');
    });

    test('documentId should start with "untis_" when fromUntis is true', () {
      // setup
      final subject = subjectWithFalseData(fromUntis: true, id: 123);
      // verify
      expect(subject.documentId, 'untis_123');
    });

    test('documentId should start with "custom_" when fromUntis is false', () {
      // setup
      final subject = subjectWithFalseData(fromUntis: false, id: 456);
      // verify
      expect(subject.documentId, 'custom_456');
    });
  });
}

Subject subjectWithFalseData({bool? fromUntis, int? id}) {
  return Subject.fromDocument({
    'backColor': 0xFF123456,
    'foreColor': 0xFFABCDEF,
    'id': id ?? 42,
    'fromUntis': fromUntis ?? false,
    'name': 'Mathematik',
    'shortName': 'MA',
  });
}
