import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import '../../database/models/subject.dart';
import '../../provider/subject_provider.dart';
import '../../utilities/common.dart';
import '../../widgets/search_screen.dart';
import '../../widgets/subject_tile.dart';

/// A screen that allows users to choose a [Subject].
///
/// This widget:
/// - Retrieves all subjects from [SubjectProvider]
/// - Displays them in a searchable list
/// - Filters subjects based on input text
/// - Returns the selected subject via [onSubjectSelected]
/// - Pops this route once a subject is chosen
class SubjectSelection extends StatefulWidget {
  /// Callback executed when a subject is selected.
  ///
  /// If null, no callback will be triggered.
  final void Function(Subject)? onSubjectSelected;

  const SubjectSelection({super.key, this.onSubjectSelected});

  @override
  State<SubjectSelection> createState() => _SubjectSelectionState();
}

class _SubjectSelectionState extends State<SubjectSelection> {
  /// Search query used to filter subjects.
  String query = '';

  @override
  Widget build(BuildContext context) {
    /// Reads the full list of subjects from the provider.
    final subjects = context.watch<SubjectProvider>().subjects;

    /// Filters subjects by visibility and by name or shortName depending on
    /// `query`.
    final filteredSubjects = subjects.where((subject) {
      return subject.visible &&
          (subject.name.toLowerCase().contains(query.toLowerCase()) ||
              subject.shortName.toLowerCase().contains(query.toLowerCase()));
    }).toList();

    // IDEA: Perhaps a special section for "today's subjects" could be added?
    // final untisProvider = context.watch<UntisProvider>();
    // final todaySubjectIds = untisProvider.untisSubjectsLoaded
    //     ? untisProvider.todaySubjects
    //           .map((subject) => subject.documentId)
    //           .toSet()
    //     : <String>{};
    // final todaySubjects = filteredSubjects
    //     .where((subject) => todaySubjectIds.contains(subject.documentId))
    //     .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Fach auswählen')),
      body: withConstrainedWidth(
        context,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: filteredSubjects.isEmpty
              ? _buildEmpty(subjects, context)
              : SearchScreen(
                  searchableItems: filteredSubjects,
                  searchHint: 'Fach suchen...',
                  getQueryString: (Subject subject) =>
                      '${subject.name} ${subject.shortName}'.toLowerCase(),
                  buildTile:
                      (
                        BuildContext context,
                        Subject subject,
                        void Function() onTap,
                      ) => SubjectTile(subject: subject, onTap: onTap),
                  onSelected: (Subject subject) {
                    widget.onSubjectSelected?.call(subject);
                    Navigator.pop(context);
                  },
                ),
        ),
      ),
    );
  }

  Center _buildEmpty(List<Subject> subjects, BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            subjects.isEmpty ? Icons.library_books_outlined : Icons.search_off,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const Gap(12),
          Text(
            subjects.isEmpty
                ? 'Keine Fächer vorhanden'
                : 'Kein Fach gefunden für „$query"',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
