import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/models/homework.dart';
import '../provider/config_provider.dart';
import '../provider/homeworks_provider.dart';
import '../utilities/common.dart';
import '../utilities/homeworks_list.dart';
import 'fab.dart';
import 'homeworks_list.dart';

class HomeDayCard extends StatelessWidget {
  final DateTime date;
  final bool includeOverdueHomeworks;
  final bool onlyHomeworksAfterDate;

  const HomeDayCard({
    super.key,
    required this.date,
    this.onlyHomeworksAfterDate = false,
    this.includeOverdueHomeworks = false,
  });

  Homeworks sortByCompletions(Homeworks homeworks) {
    List<Homework> completed = homeworks.completed.sortedBy((h) => h.dueDate!);
    List<Homework> notCompleted = homeworks.notCompleted.sortedBy(
      (h) => h.dueDate!,
    );
    return Homeworks(homeworks: [...notCompleted, ...completed]);
  }

  @override
  Widget build(BuildContext context) {
    double maxDayCardWidth = context.select<ConfigProvider, double>(
      (config) => config.maxDayCardWidth,
    );

    HomeworksProvider homeworksProvider = context.watch<HomeworksProvider>();
    Homeworks homeworksForDate = onlyHomeworksAfterDate
        ? homeworksProvider.homeworks.getForAfterDate(date)
        : homeworksProvider.homeworks.getForDate(date);
    Homeworks overdueHomeworks = includeOverdueHomeworks
        ? homeworksProvider.homeworks.overdue
        : Homeworks(homeworks: []);
    Homeworks homeworksWithoutDueDate = onlyHomeworksAfterDate
        ? homeworksProvider.homeworks.withoutDueDate
        : Homeworks(homeworks: []);

    bool hasNoHomeworks =
        homeworksProvider.homeworksLoaded &&
        homeworksForDate.isEmpty &&
        overdueHomeworks.isEmpty &&
        homeworksWithoutDueDate.isEmpty;

    double widthFactor = hasNoHomeworks ? 1 / 2 : 1;

    TextStyle? dateStyle = Theme.of(context).textTheme.headlineSmall;

    return SizedBox(
      width: maxDayCardWidth * widthFactor,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: kGapSize / 2),
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: kGapSize),
          child: hasNoHomeworks
              ? buildEmptyState(dateStyle)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      onlyHomeworksAfterDate
                          ? 'Alles nach ${getWeekday(date)}'
                          : '${getWeekday(date)}, ${date.day}.${date.month}.${date.year}',
                      style: dateStyle,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: kGapSize),
                      child: Divider(),
                    ),
                    homeworksProvider.homeworksLoaded
                        ? buildHomeworksList(
                            homeworksForDate: sortByCompletions(
                              homeworksForDate,
                            ),
                            overdueHomeworks: sortByCompletions(
                              overdueHomeworks,
                            ),
                            homeworksWithoutDueDate: sortByCompletions(
                              homeworksWithoutDueDate,
                            ),
                          )
                        : const Center(child: CircularProgressIndicator()),
                  ],
                ),
        ),
      ),
    );
  }

  Expanded buildHomeworksList({
    required Homeworks homeworksForDate,
    Homeworks? overdueHomeworks,
    Homeworks? homeworksWithoutDueDate,
  }) {
    double containerMargin = kGapSize / 2;
    double containerBorderWidth = 1.0;
    double containerPadding = kGapSize / 2 - containerBorderWidth;

    bool showWithoutDueDate =
        homeworksWithoutDueDate != null && homeworksWithoutDueDate.isNotEmpty;

    return Expanded(
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Column(
          children: [
            if (overdueHomeworks != null && overdueHomeworks.isNotEmpty)
              HomeworksList(
                homeworks: overdueHomeworks,
                padding: homeworksForDate.isNotEmpty || showWithoutDueDate
                    ? const EdgeInsets.all(0)
                    : null,
                onCompleted: (_) {},
                withDateInfo: true,
                decoration: (
                  containerMargin: containerMargin,
                  containerPadding: containerPadding,
                  containerBorderWidth: containerBorderWidth,
                  label: 'alte Hausaufgaben',
                  borderColor: Colors.grey,
                ),
              ),
            if (homeworksForDate.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kGapSize),
                child: HomeworksList(
                  padding: showWithoutDueDate ? EdgeInsets.all(0) : null,
                  homeworks: homeworksForDate,
                  onCompleted: (_) {},
                  withDateInfo: onlyHomeworksAfterDate,
                ),
              ),
            if (homeworksWithoutDueDate != null &&
                homeworksWithoutDueDate.isNotEmpty)
              HomeworksList(
                homeworks: homeworksWithoutDueDate,
                padding: const EdgeInsets.all(0),
                onCompleted: (_) {},
                withDateInfo: true,
                decoration: (
                  containerMargin: containerMargin,
                  containerPadding: containerPadding,
                  containerBorderWidth: containerBorderWidth,
                  label: 'Hausaufgaben ohne Abgabedatum',
                  borderColor: Colors.grey,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget buildEmptyState(TextStyle? dateStyle) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          onlyHomeworksAfterDate
              ? 'Alles nach ${getWeekday(date)}'
              : getWeekday(date),
          style: dateStyle,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: kGapSize),
          child: Divider(),
        ),
        Expanded(
          child: Center(
            child: RotatedBox(
              quarterTurns: 3,
              child: Text('Keine Hausaufgaben🎉', style: dateStyle),
            ),
          ),
        ),
      ],
    );
  }
}
