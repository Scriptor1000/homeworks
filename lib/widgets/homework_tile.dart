import 'package:collection/collection.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../database/models/homework.dart';
import '../database/models/subject.dart';
import '../provider/homeworks_provider.dart';
import '../provider/subject_provider.dart';
import '../utilities/common.dart';
import '../utilities/constants.dart';
import '../utilities/enums.dart';
import '../utilities/global_snackbar.dart';
import 'fab.dart';
import 'subject_avatar.dart';
import '../routes/typesafe_router.dart';

/// A [ListTile] widget that displays homework information and allows marking it as completed.
///
/// When the homework is completed, the [onCompleted] callback is triggered.
class HomeworkTile extends StatelessWidget {
  const HomeworkTile({
    super.key,
    required this.homework,
    required this.statusChange,
    required this.withDateInfo,
  });

  final Homework homework;
  final VoidCallback statusChange;

  final bool withDateInfo;

  String? dueDateText(DateTime? dueDateTime) {
    if (dueDateTime == null) return null;
    if (!withDateInfo) {
      return homework.type != .appointment ? formatHourMinute(dueDateTime) : '';
    }
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

    final weekday = getWeekday(dueDateTime);

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
        text += ', bis ${formatHourMinute(dueDateTime)}';
      }
    } else if (dayDifference == 1) {
      text = 'Morgen';
      if (homework.type != HomeworkType.appointment) {
        text += ', bis ${formatHourMinute(dueDateTime)}';
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

    Color backColor =
        subject?.backColor.harmonizeWith(
          Theme.of(context).colorScheme.primary,
        ) ??
        Theme.of(context).colorScheme.error;

    final dateText = dueDateText(homework.dueDate);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BorderRadiusConstants.homeworks),
        border: Border.all(color: backColor, width: 2),
        color: homework.type == HomeworkType.exam
            ? backColor.withAlpha(50)
            : null,
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        leading: SubjectAvatar(subject: subject),
        title: Text(
          '${homework.type == HomeworkType.exam ? 'LK: ' : ''}${homework.title}',
        ),
        subtitle: dateText != null ? Text(dateText) : null,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        backgroundColor: homework.type == HomeworkType.exam
            ? Colors.transparent
            : null,

        trailing: _buildTrailing(
          subject,
          context.read<HomeworksProvider>(),
          Theme.of(context),
        ),

        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: kGapSize / 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDescription(),
                        littleGap(),

                        Text(
                          'Erstellt am ${getWeekday(homework.createdAt)}, ${DateFormat('dd.MM').format(homework.createdAt)}',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        EditHomeworkRoute(
                          homeworkId: homework.documentId,
                        ).go(context);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        await context.read<HomeworksProvider>().deleteHomework(
                          homework.id,
                        );
                        showSnackBar('Hausaufgabe gelöscht');
                      },
                    ),
                  ],
                ),

                littleGap(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BorderRadiusConstants.homeworks),
        color: Colors.grey.withAlpha(30),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: kGapSize,
        vertical: kGapSize / 2,
      ),
      child: homework.description.isNotEmpty
          ? Text(homework.description, style: const TextStyle(fontSize: 16))
          : Row(
              children: [
                Text(' '),
                Expanded(
                  child: Divider(
                    thickness: 2,
                    color: Colors.grey.withAlpha(100),
                  ),
                ),
                Text(' '),
              ],
            ),
    );
  }

  Widget _buildTrailing(
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
    Row finalRow({
      required bool withReviveIfPossible,
      required bool withEmoji,
      required bool completeOnlyWhenDue,
      required bool withTime,
    }) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (withEmoji && homework.emoji != null)
            Text(homework.emoji!.emoji, style: theme?.textTheme.headlineSmall),
          if (withTime && homework.dueDate != null)
            Text(
              '${homework.dueDate!.hour.toString().padLeft(2, '0')}:'
              '${homework.dueDate!.minute.toString().padLeft(2, '0')}',
              style: theme?.textTheme.bodyLarge,
            ),
          if (withReviveIfPossible &&
              (homework.dueDate != null &&
                  homework.dueDate!.isBefore(DateTime.now()) &&
                  !homework.isCompleted &&
                  subject != null &&
                  subject.nextLesson != null))
            IconButton(
              onPressed: () {
                homeworksProvider.newDueDate(homework.id, subject.nextLesson!);
              },
              icon: Icon(Icons.replay_rounded),
            ),
          if (!completeOnlyWhenDue ||
              homework.dueDate != null &&
                  DateTime.now().isAfter(homework.dueDate!))
            completeButton,
        ],
      );
    }

    return switch (homework.type) {
      HomeworkType.homework => finalRow(
        withReviveIfPossible: true,
        withEmoji: true,
        completeOnlyWhenDue: false,
        withTime: false,
      ),
      HomeworkType.exam => finalRow(
        withReviveIfPossible: true,
        withEmoji: true,
        completeOnlyWhenDue: true,
        withTime: false,
      ),
      HomeworkType.appointment => finalRow(
        withReviveIfPossible: false,
        withEmoji: true,
        completeOnlyWhenDue: true,
        withTime: true,
      ),
    };
  }
}
