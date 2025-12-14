import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/models/subject.dart';
import '../../provider/subject_provider.dart';
import '../../widgets/search_screen.dart';
import '../../widgets/subject_tile.dart';

/// Widget to select a subject
///
/// This widget displays a list of [Subject] from the [SubjectProvider].
/// You can give it a callback [onSubjectSelected] to handle the selected subject,
/// which will only be called if the user selects a subject.
/// After a selection is made, it will pop the current screen.
class SubjectSelection extends StatelessWidget {
  final void Function(Subject)? onSubjectSelected;
  const SubjectSelection({super.key, this.onSubjectSelected});

  @override
  Widget build(BuildContext context) {
    final subjects = context
        .watch<SubjectProvider>()
        .subjects
        .where((subject) => subject.visible)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Fach auswählen')),
      body: subjects.isEmpty
          ? buildEmpty()
          : SearchScreen<Subject>(
              searchableItems: subjects,
              searchHint: 'Fach suchen...',
              getQueryString: (subject) =>
                  '${subject.name} ${subject.shortName}',
              buildTile: _buildSubjectTile,
              onSelected: (s) {
                onSubjectSelected?.call(s);
                Navigator.pop(context, s);
              },
            ),
    );
  }

  Widget buildEmpty() {
    return Center(
      child: Text(
        'Keine Fächer vorhanden. \n'
        'Um Fächer hinzuzufügen, musst du dein Untis Konto verbinden.\n'
        'Weil jede Hausaufgabe einem Fach zugeordnet sein muss, '
        'kannst du ohne diese Verbindung keine Hausaufgaben erstellen.'
        'Falls du dies bereits getan hast, kann es sein dass alle Fächer ausgeblendet sind. ',
      ),
    );
  }

  Widget _buildSubjectTile(
    BuildContext context,
    Subject subject,
    VoidCallback onTap,
  ) {
    return SubjectTile(subject: subject, onTap: () => onTap());
  }
}
