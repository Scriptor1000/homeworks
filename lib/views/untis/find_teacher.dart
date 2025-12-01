import 'package:collection/collection.dart';
import 'package:dart_untis_mobile/src/objects.dart';
import 'package:dart_untis_mobile/src/timetable_objects.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../provider/untis_provider.dart';

class FindTeacher extends StatefulWidget {
  final UntisElementDescriptor teacher;
  const FindTeacher({super.key, required this.teacher});

  @override
  State<FindTeacher> createState() => _FindTeacherState();
}

class _FindTeacherState extends State<FindTeacher> {
  @override
  Widget build(BuildContext context) {
    final UntisProvider provider = context.watch();
    final teacher = provider.untisTeachers.firstWhereOrNull(
      (t) => t.id == widget.teacher,
    );
    if (teacher == null) {
      // TODO switch status
      return Scaffold(
        appBar: AppBar(title: Text('Fehler')),
        body: Center(
          child: Text('Kein Lehrer mit ID: ${widget.teacher.id} gefunden'),
        ),
      );
    }
    final stream = provider.findTeacher(widget.teacher);
    return Scaffold(
      appBar: AppBar(title: Text(teacher.fullName)),
      body: StreamBuilder<TeacherSearchResult>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            Sentry.captureException(
              snapshot.error,
              stackTrace: snapshot.stackTrace,
            );
            return Center(child: Text('Fehler: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final result = snapshot.data!;
          return _buildResult(result);
        },
      ),
    );
  }

  ListView _buildResult(TeacherSearchResult result) {
    final periods = result.periods.toList()
      ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    List<Widget> widgets = [
      Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text(
          'Stunden in den nächsten 7 Tagen:',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    ];

    for (var index = 0; index < periods.length; index++) {
      if (index == 0 ||
          periods[index].startDateTime.day !=
              periods[index - 1].startDateTime.day) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: _formatDate(periods[index]),
          ),
        );
      }
      widgets.add(_buildTile(periods[index]));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [...widgets, _buildInfo(result)],
    );
  }

  Text _formatDate(UntisPeriod period) {
    return Text(
      '${period.startDateTime.day.toString().padLeft(2, '0')}.${period.startDateTime.month.toString().padLeft(2, '0')}.${period.startDateTime.year}',
      style: Theme.of(context).textTheme.titleMedium,
    );
  }

  Widget _buildInfo(TeacherSearchResult result) {
    if (result.currentClass == null) {
      return result.periods.isEmpty
          ? const Center(child: Text('Es wurden keine Einträge gefunden'))
          : const Center(child: Text('Keine weiteren Einträge gefunden'));
    } else {
      return Center(
        child: Text('Schaue im Stundenplan der ${result.currentClass}'),
      );
    }
  }

  ListTile _buildTile(UntisPeriod period) {
    String rooms = period.rooms.map((r) => r.name).join(', ');
    if (rooms.isEmpty) {
      rooms = 'Kein Raum angegeben';
    }
    return ListTile(
      title: Text(rooms),
      subtitle: Text(period.subject?.longName ?? 'Ohne Fach'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _formatTime(period.startDateTime),
          const Text('–'),
          _formatTime(period.endDateTime),
        ],
      ),
    );
  }

  Text _formatTime(DateTime time) {
    return Text(
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
    );
  }
}
