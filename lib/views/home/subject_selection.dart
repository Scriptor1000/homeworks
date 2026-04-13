import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import '../../database/models/subject.dart';
import '../../provider/subject_provider.dart';
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

    /// Filters subjects by name or shortName depending on `query`.
    final filteredSubjects = subjects.where((subject) {
      return subject.name.toLowerCase().contains(query.toLowerCase()) ||
          subject.shortName.toLowerCase().contains(query.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fach auswählen'), // "Select subject"
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Stack(
          children: [
            Column(
              children: [
                // TODO: Add "Today's subjects" section
                Expanded(
                  child: ListView.builder(
                    /// +1 so we can add spacing at the end of the list
                    itemCount: filteredSubjects.length + 1,
                    itemBuilder: (context, index) {
                      if (index == filteredSubjects.length) {
                        // Adds extra spacing at bottom so the SearchBar doesn't overlap list
                        return const Gap(56 + 16);
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: SubjectTile(
                          subject: filteredSubjects[index],
                          onTap: () {
                            print(
                                'Selected subject: ${filteredSubjects[index].name}');

                            /// Runs callback if provided
                            widget.onSubjectSelected
                                ?.call(filteredSubjects[index]);

                            /// Close this screen
                            Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            /// Bottom SearchBar overlay
            Container(
              alignment: Alignment.bottomCenter,
              margin: const EdgeInsets.only(bottom: 16),
              child: SearchBar(
                autoFocus: true,

                /// Called whenever text changes → update filter
                onChanged: (query) {
                  setState(() {
                    this.query = query;
                  });
                },

                /// If exactly one match → auto-select
                onSubmitted: (query) {
                  if (filteredSubjects.length == 1) {
                    print('Selected subject: ${filteredSubjects[0].name}');
                    widget.onSubjectSelected?.call(filteredSubjects[0]);
                    Navigator.pop(context);
                  }
                },

                leading: const Icon(Icons.search),
                hintText: 'Fach suchen...', // "Search subject..."
              ),
            ),
          ],
        ),
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
