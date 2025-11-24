import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import '../../database/models/subject.dart';
import '../../provider/subject_provider.dart';
import '../../widgets/subject_tile.dart';

/// Widget to select a subject
///
/// This widget displays a list of [Subject] from the [SubjectProvider].
/// You can give it a callback [onSubjectSelected] to handle the selected subject,
/// which will only be called if the user selects a subject.
/// After a selection is made, it will pop the current screen.
class SubjectSelection extends StatefulWidget {
  final void Function(Subject)? onSubjectSelected;

  const SubjectSelection({super.key, this.onSubjectSelected});

  @override
  State<SubjectSelection> createState() => _SubjectSelectionState();
}

class _SubjectSelectionState extends State<SubjectSelection> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final subjects = context
        .watch<SubjectProvider>()
        .subjects
        .where((subject) => subject.visible)
        .toList();

    final filteredSubjects = subjects.where((subject) {
      return subject.name.toLowerCase().contains(query.toLowerCase()) ||
          subject.shortName.toLowerCase().contains(query.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fach auswählen'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Stack(
          children: [
            subjects.isNotEmpty
                ? Column(
                    children: [
                      // TODO Todays subjects
                      buildListView(filteredSubjects)
                    ],
                  )
                : buildEmpty(),
            buildSearchBar(filteredSubjects, context)
          ],
        ),
      ),
    );
  }

  Widget buildEmpty() {
    return Center(
      child: Text('Keine Fächer vorhanden. \n'
          'Um Fächer hinzuzufügen, MUSST du Untis verknüpfen.\n'
          'Ansonsten kannst du KEINE Hausaufgaben einfügen.'),
    );
  }

  Container buildSearchBar(
      List<Subject> filteredSubjects, BuildContext context) {
    return Container(
      alignment: Alignment.bottomCenter,
      margin: const EdgeInsets.only(bottom: 16),
      // decoration: BoxDecoration(color: Colors.transparent),
      child: SearchBar(
        autoFocus: true,
        onChanged: (query) {
          setState(() {
            this.query = query;
          });
        },
        onSubmitted: (query) {
          if (filteredSubjects.length == 1) {
            print('Selected subject: ${filteredSubjects[0].name}');
            widget.onSubjectSelected?.call(filteredSubjects[0]);
            Navigator.pop(context);
          }
        },
        leading: const Icon(Icons.search),
        hintText: 'Fach suchen...',
      ),
    );
  }

  Expanded buildListView(List<Subject> filteredSubjects) {
    return Expanded(
      child: ListView.builder(
        itemCount: filteredSubjects.length + 1,
        itemBuilder: (context, index) {
          if (index == filteredSubjects.length) {
            // This could be improved
            return const Gap(56 + 16);
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SubjectTile(
              subject: filteredSubjects[index],
              onTap: () {
                print('Selected subject: ${filteredSubjects[index].name}');
                widget.onSubjectSelected?.call(filteredSubjects[index]);
                Navigator.pop(context);
              },
            ),
          );
        },
      ),
    );
  }
}
