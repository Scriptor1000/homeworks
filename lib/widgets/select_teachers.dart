import 'package:dart_untis_mobile/dart_untis_mobile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/untis_provider.dart';
import '../routes/typesafe_router.dart';
import 'search_screen.dart';

class FindTeacherTile extends StatelessWidget {
  const FindTeacherTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.search),
      title: const Text('Lehrer suchen'),
      onTap: () => _showTeacherSelectionDialog(context),
    );
  }

  Future<void> _showTeacherSelectionDialog(BuildContext context) async {
    final UntisTeacher? selectedTeacher = await Navigator.of(context)
        .push<UntisTeacher>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) {
              return Scaffold(
                appBar: AppBar(title: const Text('Lehrer auswählen')),
                body: TeacherSelection(),
              );
            },
          ),
        );

    if (selectedTeacher != null && context.mounted) {
      FindTeacherRoute(selectedTeacher.id.id).go(context);
    }
  }
}

class TeacherSelection extends StatelessWidget {
  const TeacherSelection({super.key});

  @override
  Widget build(BuildContext context) {
    final teacher = context.select(
      (UntisProvider provider) => provider.untisTeachers,
    );
    return SearchScreen<UntisTeacher>(
      things: teacher,
      searchHint: 'Lehrer Suchen...',
      getQueryString: (teacher) => teacher.fullName.toLowerCase(),
      buildTile: _buildTeacherTile,
      onSelected: (t) => Navigator.pop(context, t),
    );
  }

  Widget _buildTeacherTile(BuildContext context, UntisTeacher teacher, onTap) {
    return ListTile(title: Text(teacher.fullName), onTap: () => onTap(teacher));
  }
}
