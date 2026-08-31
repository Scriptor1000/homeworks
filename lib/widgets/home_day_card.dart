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

  const HomeDayCard({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    double maxDayCardWidth = context.select<ConfigProvider, double>(
      (config) => config.maxDayCardWidth,
    );

    HomeworksProvider homeworksProvider = context.watch<HomeworksProvider>();
    Homeworks homeworksForDate = homeworksProvider.homeworks.getForDate(date);

    return SizedBox(
      width: maxDayCardWidth,
      child: Card(
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.all(kGapSize),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${getWeekday(date)}, ${date.day}.${date.month}.${date.year}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Divider(),
              HomeworksList(homeworks: homeworksForDate, onCompleted: (_) {}),
            ],
          ),
        ),
      ),
    );
  }
}
