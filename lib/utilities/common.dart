import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../provider/config_provider.dart';

DateTime normalizeDate(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

String getWeekday(DateTime date) {
  List<String> weekdays = [
    'Montag',
    'Dienstag',
    'Mittwoch',
    'Donnerstag',
    'Freitag',
    'Samstag',
    'Sonntag',
  ];

  return weekdays[date.weekday - 1];
}

DateTime getNextWorkday(DateTime date) {
  DateTime nextDate = date.add(const Duration(days: 1));
  while (nextDate.weekday == DateTime.saturday ||
      nextDate.weekday == DateTime.sunday) {
    nextDate = nextDate.add(const Duration(days: 1));
  }
  return nextDate;
}

bool isWeekend(DateTime date) {
  return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
}

String formatHourMinute(DateTime dateTime) {
  return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
}

Widget withConstrainedWidth(BuildContext context, {required Widget child}) {
  double maxWidth = context.select(
    (ConfigProvider configProvider) => configProvider.maxWidthOnTablet,
  );

  return Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
