import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/models/homework.dart';
import '../database/models/subject.dart';
import '../provider/homeworks_provider.dart';
import '../provider/subject_provider.dart';
import '../utilities/enums.dart';
import '../utilities/global_snackbar.dart';
import 'subject_avatar.dart';
import '../routes/typesafe_router.dart';
import 'package:go_router/go_router.dart';

/// A [ListTile] widget that displays homework information and allows marking it as completed.
///
/// When the homework is completed, the [onCompleted] callback is triggered.
class HomeworkTile extends StatelessWidget {
  const HomeworkTile({
    super.key,
    required this.homework,
    required this.statusChange,
  });

  final Homework homework;
  final VoidCallback statusChange;

  String? dueDateText(DateTime? dueDateTime) {
    if (dueDateTime == null) return null;
    // Formatierung des Datums für bessere Lesbarkeit
    final now = DateTime.now();
    final nowDate = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(
      dueDateTime.year,
      dueDateTime.month,
      dueDateTime.day,
    );

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

    String text;

    if (dayDifference < 0) {
      text = 'Überfällig, vor ${-dayDifference} Tagen';
    } else if (dayDifference == 0) {
      text = 'Heute';
      if (homework.type == HomeworkType.appointment) {
        if (timeDifference.inHours > 0) {
          text +=
              ', in ${timeDifference.inHours}h und '
              '${timeDifference.inMinutes.remainder(60)}min';
        } else if (timeDifference.inMinutes > 0) {
          text += ', in ${timeDifference.inMinutes} Minuten';
        }
      } else {
        text +=
            ', bis ${dueDateTime.hour.toString().padLeft(2, '0')}:'
            '${dueDateTime.minute.toString().padLeft(2, '0')}';
      }
    } else if (dayDifference == 1) {
      text = 'Morgen';
      if (homework.type != HomeworkType.appointment) {
        text +=
            ', bis ${dueDateTime.hour.toString().padLeft(2, '0')}:'
            '${dueDateTime.minute.toString().padLeft(2, '0')}';
      }
    } else {
      text = '$weekday, in $dayDifference Tagen';
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final subject = context.select<SubjectProvider, Subject?>(
      (provider) => provider.subjects.firstWhereOrNull(
        (s) => s.documentId == homework.subjectDocId,
      ),
    );


    final dateText = dueDateText(homework.dueDate);
    return ExpansionTile(
      shape: const RoundedRectangleBorder(
        side: BorderSide.none,
      ),
      leading: SubjectAvatar(subject: subject),
      title: Text('${homework.type == HomeworkType.exam ? 'LK: ' : ''}${homework.title}'),
      subtitle: dateText != null ? Text(dateText) : null,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      backgroundColor:
      homework.type == HomeworkType.exam ? Colors.transparent : null,

      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              GoRouter.of(context).go(
                EditHomeworkRoute(homeworkId: homework.documentId).location,
              );
            },
          ),

          if (homework.isCompleted)
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green),
              onPressed: () {
                context
                    .read<HomeworksProvider>()
                    .toggleHomeworkCompletion(homework.id);
                statusChange();
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.circle_outlined),
              onPressed: () {
                context
                    .read<HomeworksProvider>()
                    .toggleHomeworkCompletion(homework.id);
                statusChange();
              },
            ),


        ],
      ),

      children: [
        Padding(
    padding: const EdgeInsets.only(
      top: 16,
      right: 16,
      bottom: 16,
      left: 16
    ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /*Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Beschreibung:',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),*/
              Row(
                children: [
                  Text(
                    'Beschreibung:',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      await context
                          .read<HomeworksProvider>()
                          .deleteHomework(homework.id);
                      showSnackBar('Hausaufgabe gelöscht');
                    },
                  ),
                ],
              ),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  homework.description.isEmpty ? '—' : homework.description,
                ),
              ),

              const SizedBox(height: 8),

            ],
          ),
        ),
      ],
    );

/*
    return ListTile(
      leading: SubjectAvatar(subject: subject),
      title: Text(
        '${homework.type == HomeworkType.exam ? 'LK: ' : ''}${homework.title}',
      ),
      subtitle: dateText != null ? Text(dateText) : null,
      tileColor: homework.type == HomeworkType.exam
          ? backColor?.withAlpha(50)
          : null,
      // textColor: homework.isExam ? foreColor : null,
      onLongPress: () async {
        // Show options to edit or delete the homework
        await homeworksProvider.deleteHomework(homework.id);
        showSnackBar('Hausaufgabe gelöscht');
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BorderRadiusConstants.homeworks),
        side: BorderSide(color: backColor ?? theme.colorScheme.error, width: 3),
      ),
      trailing: _buildTrailing(subject, homeworksProvider, theme),
    );
  }

  Widget? _buildTrailing(
    Subject? subject,
    HomeworksProvider homeworksProvider,
    ThemeData? theme,
  ) {
    final completeButton = IconButton(
      onPressed: () {
        homeworksProvider.toggleHomeworkCompletion(homework.id);
        statusChange();
      },
      icon: Icon(
        homework.isCompleted ? Icons.check_circle : Icons.circle_outlined,
        color: Colors.grey,
      ),
    );
    final rowWithRevive = Row(
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
            icon: Icon(Icons.replay_rounded),
          ),
        completeButton,
      ],
    );
    return switch (homework.type) {
      HomeworkType.homework => rowWithRevive,
      HomeworkType.exam =>
        homework.dueDate != null && DateTime.now().isAfter(homework.dueDate!)
            ? rowWithRevive
            : null,
      HomeworkType.appointment =>
        homework.dueDate != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${homework.dueDate!.hour.toString().padLeft(2, '0')}:'
                    '${homework.dueDate!.minute.toString().padLeft(2, '0')}',
                    style: theme?.textTheme.bodyLarge,
                  ),
                  completeButton,
                ],
              )
            : null,
    };
  }
}*/
  }
}
