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
                body: const TeacherSelection(),
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
    final teachers = context.select(
      (UntisProvider provider) => provider.teachers,
    );
    return SearchScreen<UntisTeacher>(
      searchableItems: teachers,
      searchHint: 'Lehrer suchen...',
      getQueryString: (teacher) => teacher.fullName,
      buildTile: _buildTeacherTile,
      onSelected: (t) => Navigator.pop(context, t),
    );
  }

  Widget _buildTeacherTile(
    BuildContext context,
    UntisTeacher teacher,
    VoidCallback onTap,
  ) {
    return ListTile(title: Text(teacher.fullName), onTap: () => onTap());
  }
}
