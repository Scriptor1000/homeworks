import 'package:collection/collection.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/models/homework.dart';
import '../database/models/subject.dart';
import '../provider/homeworks_provider.dart';
import '../provider/subject_provider.dart';
import '../utilities/constants.dart';
import '../utilities/global_snackbar.dart';
import 'subject_avatar.dart';

/// A [ListTile] widget that displays homework information and allows marking it as completed.
///
/// When the homework is completed, the [onCompleted] callback is triggered.
class HomeworkTile extends StatelessWidget {
  const HomeworkTile({
    super.key,
    required this.homework,
    required this.onCompleted,
  });

  final Homework homework;
  final VoidCallback onCompleted;

  String? dueDateText(DateTime? dueDate) {
    if (dueDate == null) return null;
    // Formatierung des Datums für bessere Lesbarkeit
    final now = DateTime.now();
    final nowDate = DateTime(now.year, now.month, now.day);
    dueDate = DateTime(dueDate.year, dueDate.month, dueDate.day);

    final dayDifference = dueDate.difference(nowDate).inDays;

    // Wochentage auf Deutsch
    const weekdays = [
      'Montag',
      'Dienstag',
      'Mittwoch',
      'Donnerstag',
      'Freitag',
      'Samstag',
      'Sonntag',
    ];
    final weekday = weekdays[dueDate.weekday - 1];

    // Text für nächste Stunde
    if (dayDifference < 0) {
      return 'Überfällig, vor ${-dayDifference} Tagen';
    } else if (dayDifference == 0) {
      return 'Heute';
    } else if (dayDifference == 1) {
      return 'Morgen';
    } else {
      return '$weekday, in $dayDifference Tagen';
    }
  }

  @override
  Widget build(BuildContext context) {
    final subject = context.select<SubjectProvider, Subject?>(
      (provider) => provider.subjects.firstWhereOrNull(
        (s) => s.documentId == homework.subjectDocId,
      ),
    );
    final backColor = subject?.backColor.harmonizeWith(
      Theme.of(context).primaryColor,
    );
    final colorScheme = Theme.of(context).colorScheme;

    final dateText = dueDateText(homework.dueDate);

    return ListTile(
      leading: SubjectAvatar(subject: subject),
      title: Text('${homework.isExam ? 'LK: ' : ''}${homework.title}'),
      subtitle: dateText != null ? Text(dateText) : null,
      tileColor: homework.isExam ? backColor?.withAlpha(50) : null,
      // textColor: homework.isExam ? foreColor : null,
      onLongPress: () async {
        // Show options to edit or delete the homework
        await context.read<HomeworksProvider>().deleteHomework(homework);
        showSnackBar('Hausaufgabe gelöscht');
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BorderRadiusConstants.homeworks),
        side: BorderSide(color: backColor ?? colorScheme.error, width: 3),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (homework.dueDate != null &&
              homework.dueDate!.isBefore(DateTime.now()) &&
              !homework.isCompleted &&
              subject != null &&
              subject.nextLesson != null)
            IconButton(
              onPressed: () {
                context.read<HomeworksProvider>().newDueDate(
                  homework,
                  subject.nextLesson!,
                );
              },
              icon: Icon(Icons.replay_rounded),
            ),
          homework.isCompleted
              ? const Icon(Icons.check_circle, color: Colors.green)
              : IconButton(
                  onPressed: () {
                    context.read<HomeworksProvider>().completeHomework(
                      homework,
                    );
                    onCompleted();
                  },
                  icon: const Icon(Icons.circle_outlined, color: Colors.grey),
                ),
        ],
      ),
    );
  }
}
