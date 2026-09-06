import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/config_provider.dart';
import '../provider/homeworks_provider.dart';
import '../utilities/common.dart';
import '../utilities/homeworks_list.dart';
import 'fab.dart';
import 'homeworks_list.dart';

class HomeDayCard extends StatelessWidget {
  final DateTime date;
  final bool onlyHomeworksAfterDate;

  const HomeDayCard({
    super.key,
    required this.date,
    this.onlyHomeworksAfterDate = false,
  });

  @override
  Widget build(BuildContext context) {
    double maxDayCardWidth = context.select<ConfigProvider, double>(
      (config) => config.maxDayCardWidth,
    );

    HomeworksProvider homeworksProvider = context.watch<HomeworksProvider>();
    Homeworks homeworksForDate = onlyHomeworksAfterDate
        ? homeworksProvider.homeworks.getForAfterDate(date)
        : homeworksProvider.homeworks.getForDate(date);

    bool hasNoHomeworks =
        homeworksForDate.isEmpty && homeworksProvider.homeworksLoaded;

    double width_factor = hasNoHomeworks ? 1 / 2 : 1;

    TextStyle? dateStyle = Theme.of(context).textTheme.headlineSmall;

    return SizedBox(
      width: maxDayCardWidth * width_factor,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: kGapSize / 2),
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.all(kGapSize),
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
                    Divider(),
                    homeworksProvider.homeworksLoaded
                        ? buildHomeworksList(homeworksForDate)
                        : const Center(child: CircularProgressIndicator()),
                  ],
                ),
        ),
      ),
    );
  }

  Expanded buildHomeworksList(Homeworks homeworksForDate) {
    return Expanded(
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: HomeworksList(
          homeworks: homeworksForDate,
          onCompleted: (_) {},
          withDateInfo: onlyHomeworksAfterDate,
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
        Divider(),
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
