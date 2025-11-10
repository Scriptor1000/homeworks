import 'package:flutter_test/flutter_test.dart';
import 'package:homeworks/database/models/homework.dart';
import 'package:homeworks/utilities/enums.dart';

void main() {
  group('Homework Model Tests', () {
    final now = DateTime.now();

    test('homeworks should be identical when stored and read from database',
        () {
      // setup
      final originalHomework = homeworkWithFalseData();
      // test
      final document = originalHomework.toDocument();
      final readHomework = Homework.fromDocument(document);
      // verify
      expect(readHomework.id, equals(originalHomework.id));
      expect(readHomework.title, equals(originalHomework.title));
      expect(readHomework.description, equals(originalHomework.description));
      expect(readHomework.subjectDocId, equals(originalHomework.subjectDocId));
      expect(readHomework.toNextLesson, equals(originalHomework.toNextLesson));
      expect(readHomework.isCompleted, equals(originalHomework.isCompleted));
      expect(readHomework.fromUntis, equals(originalHomework.fromUntis));
      expect(readHomework.dueDate, equals(originalHomework.dueDate));
      expect(readHomework.createdAt, equals(originalHomework.createdAt));
      expect(readHomework.type, equals(originalHomework.type));
      expect(readHomework.createdAt, isA<DateTime>());
    });

    test('homework should be urgent when due tomorrow', () {
      // setup
      final homework = homeworkWithFalseData(
        dueDate: now.add(Duration(days: 1)),
        isExam: false,
      );
      // verify
      expect(homework.isUrgent, isTrue);
    });

    test('homework should not be urgent when due in 2 days', () {
      // setup
      final homework = homeworkWithFalseData(
        dueDate: now.add(Duration(days: 2)),
        isExam: false,
      );
      // verify
      expect(homework.isUrgent, isFalse);
    });

    test('exam should be urgent when due in 3 days', () {
      // setup
      final homework = homeworkWithFalseData(
        dueDate: now.add(Duration(days: 3)),
        isExam: true,
      );
      // verify
      expect(homework.isUrgent, isTrue);
    });

    test('exam should not be urgent when due in 4 days', () {
      // setup
      final homework = homeworkWithFalseData(
        dueDate: now.add(Duration(days: 4)),
        isExam: true,
      );
      // verify
      expect(homework.isUrgent, isFalse);
    });
  });
}

Homework homeworkWithFalseData({DateTime? dueDate, bool? isExam}) {
  return Homework(
    title: 'Test Homework',
    description: 'This is a test homework',
    subjectDocId: 'untis_test',
    toNextLesson: false,
    isCompleted: false,
    fromUntis: false,
    dueDate: dueDate ?? DateTime.now(),
    type: (isExam ?? false) ? HomeworkType.exam : HomeworkType.homework,
  );
}
