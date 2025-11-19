import 'package:collection/collection.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/models/homework.dart';
import '../database/models/subject.dart';
import '../provider/homeworks_provider.dart';
import '../provider/subject_provider.dart';
import '../utilities/constants.dart';
import '../utilities/enums.dart';
import '../utilities/global_snackbar.dart';
import 'subject_avatar.dart';

/// A [ListTile] widget that displays homework information and allows marking it as completed.
///
/// When the homework is completed or uncompleted, the [statusChange] callback is triggered.
class HomeworkTile extends StatelessWidget {
  const HomeworkTile(
      {super.key, required this.homework, required this.statusChange});

  final Homework homework;
  final VoidCallback statusChange;

  String? dueDateText(DateTime? dueDateTime) {
    if (dueDateTime == null) return null;
    // Formatierung des Datums für bessere Lesbarkeit
    final now = DateTime.now();
    final nowDate = DateTime(now.year, now.month, now.day);
    final dueDay =
        DateTime(dueDateTime.year, dueDateTime.month, dueDateTime.day);

    final dayDifference = dueDay.difference(nowDate).inDays;
    final timeDifference = dueDateTime.difference(now);

    // Wochentage auf Deutsch
    const weekdays = [
      'Montag',
      'Dienstag',
      'Mittwoch',
      'Donnerstag',
      'Freitag',
      'Samstag',
      'Sonntag'
    ];
    final weekday = weekdays[dueDay.weekday - 1];

    // Text für nächste Stunde
    if (dayDifference < 0) {
      return 'Überfällig, vor ${-dayDifference} Tagen';
    } else if (dayDifference == 0) {
      if (timeDifference.inHours < 1) {
        return 'in ${timeDifference.inMinutes} Minuten';
      } else if (timeDifference.inMinutes > 0) {
        return 'in ${timeDifference.inHours} Stunden und '
            '${timeDifference.inMinutes.remainder(60)} Minuten';
      } else {
        return 'Heute';
      }
    } else if (dayDifference == 1) {
      return 'Morgen, um ${dueDateTime.hour.toString().padLeft(2, '0')}:'
          '${dueDateTime.minute.toString().padLeft(2, '0')} Uhr';
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
    final homeworksProvider = context.read<HomeworksProvider>();

    final backColor = subject?.backColor.harmonizeWith(
      Theme.of(context).primaryColor,
    );
    final theme = Theme.of(context);

    final dateText = dueDateText(homework.dueDate);

    return ListTile(
      leading: SubjectAvatar(
        subject: subject,
      ),
      title: Text(
          '${homework.type == HomeworkType.exam ? 'LK: ' : ''}${homework.title}'),
      subtitle: dateText != null ? Text(dateText) : null,
      tileColor:
          homework.type == HomeworkType.exam ? backColor?.withAlpha(50) : null,
      // textColor: homework.isExam ? foreColor : null,
      onLongPress: () async {
        // Show options to edit or delete the homework
        await homeworksProvider.deleteHomework(homework.id);
        showSnackBar('Hausaufgabe gelöscht');
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BorderRadiusConstants.homeworks),
        side: BorderSide(
          color: backColor ?? theme.colorScheme.error,
          width: 3,
        ),
      ),
      trailing: _buildTrailing(subject, homeworksProvider, theme),
    );
  }

  Widget? _buildTrailing(
      Subject? subject, HomeworksProvider homeworksProvider, ThemeData? theme) {
    var row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (homework.dueDate != null &&
            homework.dueDate!.isBefore(DateTime.now()) &&
            !homework.isCompleted &&
            subject != null &&
            subject.nextLesson != null)
          IconButton(
              onPressed: () {
                homeworksProvider.newDueDate(homework.id, subject.nextLesson!);
              },
              icon: Icon(Icons.replay_rounded)),
        IconButton(
            onPressed: () {
              homeworksProvider.toggleHomeworkCompletion(homework.id);
              statusChange();
            },
            icon: Icon(
                homework.isCompleted
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                color: Colors.grey)),
      ],
    );
    return switch (homework.type) {
      HomeworkType.homework => row,
      HomeworkType.exam =>
        homework.dueDate != null && DateTime.now().isAfter(homework.dueDate!)
            ? row
            : null,
      HomeworkType.appointment => homework.dueDate != null
          ? Text(
              '${homework.dueDate!.hour.toString().padLeft(2, '0')}:'
              '${homework.dueDate!.minute.toString().padLeft(2, '0')}',
              style: theme?.textTheme.bodyLarge,
            )
          : null,
    };
  }
}
