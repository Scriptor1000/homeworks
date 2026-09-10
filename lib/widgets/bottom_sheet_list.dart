import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/models/subject.dart';
import '../provider/subject_provider.dart';
import '../utilities/enums.dart';
import 'fab.dart';
import 'subject_tile.dart';

/// A widget for displaying a list of subjects in a bottom sheet.
/// It allows the user to import or remove subjects from Untis or Firestore.
class SubjectBottomSheetContent extends StatefulWidget {
  final String title;
  final List<Subject> initialSubjects;
  final SubjectListType subjectListType;
  final GlobalKey<AnimatedListState> listKey = GlobalKey();

  SubjectBottomSheetContent({
    super.key,
    required this.title,
    required this.initialSubjects,
    required this.subjectListType,
  });

  @override
  State<SubjectBottomSheetContent> createState() =>
      _SubjectBottomSheetContentState();
}

class _SubjectBottomSheetContentState extends State<SubjectBottomSheetContent> {
  late List<Subject> _subjects;
  final Map<int, bool> _isProcessing = {};

  @override
  void initState() {
    super.initState();
    _subjects = List<Subject>.from(widget.initialSubjects);
  }

  Future<void> _handleImport(Subject subject, int index) async {
    if (_isProcessing[subject.id] == true) return;

    setState(() {
      _isProcessing[subject.id] = true;
    });

    SubjectProvider provider = Provider.of<SubjectProvider>(
      context,
      listen: false,
    );
    await provider.addSubject(subject);
    _removeSubjectFromList(subject, index);

    if (mounted) {
      setState(() {
        _isProcessing.remove(subject.id);
      });
    }
  }

  Future<void> _handleVisibilityToggle(Subject subject, int index) async {
    if (_isProcessing[subject.id] == true) return;

    setState(() {
      _isProcessing[subject.id] = true;
    });

    SubjectProvider provider = context.read();
    await provider.toggleSubjectVisibility(subject.documentId);

    if (mounted) {
      setState(() {
        _isProcessing.remove(subject.id);
      });
    }
  }

  Future<void> _handleRemove(Subject subject, int index) async {
    if (_isProcessing[subject.id] == true) return;

    setState(() {
      _isProcessing[subject.id] = true;
    });

    SubjectProvider provider = context.read();
    await provider.removeSubject(subject);
    _removeSubjectFromList(subject, index);

    if (mounted) {
      setState(() {
        _isProcessing.remove(subject.id);
      });
    }
  }

  Future<void> _importAllSubjects() async {
    if (_subjects.isEmpty) return;

    setState(() {
      // Setze alle Elemente auf "wird verarbeitet"
      for (var subject in _subjects) {
        _isProcessing[subject.id] = true;
      }
    });

    SubjectProvider provider = Provider.of<SubjectProvider>(
      context,
      listen: false,
    );

    for (var subject in List<Subject>.from(_subjects)) {
      await provider.addSubject(subject);
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _removeAllSubjects() async {
    if (_subjects.isEmpty) return;

    // Bestätigungsdialog zeigen
    bool confirm =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.delete_sweep, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Alle Fächer löschen'),
                ],
              ),
              content: Text(
                'Möchtest du wirklich alle ${_subjects.length} Fächer löschen?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Abbrechen'),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Alle löschen'),
                ),
              ],
              elevation: 4,
            );
          },
        ) ??
        false;

    if (!confirm || !mounted) return;

    setState(() {
      // Setze alle Elemente auf "wird verarbeitet"
      for (var subject in _subjects) {
        _isProcessing[subject.id] = true;
      }
    });

    SubjectProvider provider = Provider.of<SubjectProvider>(
      context,
      listen: false,
    );

    for (var subject in List<Subject>.from(_subjects)) {
      await provider.removeSubject(subject);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _removeSubjectFromList(Subject subject, int index) {
    if (_subjects.length == 1) {
      // Wenn es das letzte Element ist, schließe das BottomSheet ohne das Element zu entfernen
      // Dies sorgt dafür, dass das Fach weiterhin in der Liste ist, wenn das Sheet wieder geöffnet wird

      // Das Schließen des BottomSheets ohne Verzögerung
      Navigator.pop(context);
    } else {
      // Bei mehr als einem Element: Normal mit Animation entfernen
      final removedItem = _subjects.removeAt(index);

      // Animation für das entfernte Element
      widget.listKey.currentState?.removeItem(
        index,
        (context, animation) => _buildRemovedItem(removedItem, animation),
        duration: const Duration(milliseconds: 300),
      );
    }
  }

  Future<bool> _showConfirmationDialog(Subject subject) async {
    // Formatiere das Datum schön, wenn vorhanden
    String nextLessonText = '';
    if (subject.nextLesson != null) {
      // Formatierung des Datums für bessere Lesbarkeit
      final now = DateTime.now();
      final nextLesson = subject.nextLesson!;
      final isToday =
          nextLesson.day == now.day &&
          nextLesson.month == now.month &&
          nextLesson.year == now.year;
      final isTomorrow =
          nextLesson.day == now.add(const Duration(days: 1)).day &&
          nextLesson.month == now.add(const Duration(days: 1)).month &&
          nextLesson.year == now.add(const Duration(days: 1)).year;

      // Wochentage auf Deutsch
      const weekdays = [
        'Montag',
        'Dienstag',
        'Mittwoch',
        'Donnerstag',
        'Freitag',
        'Samstag',
        'Sonntag',
      ];
      final weekday = weekdays[nextLesson.weekday - 1];

      // Zeit formatieren
      final hour = nextLesson.hour.toString().padLeft(2, '0');
      final minute = nextLesson.minute.toString().padLeft(2, '0');
      final time = '$hour:$minute Uhr';

      // Text für nächste Stunde
      if (isToday) {
        nextLessonText = 'Heute um $time';
      } else if (isTomorrow) {
        nextLessonText = 'Morgen um $time';
      } else {
        // Datum formatieren
        final day = nextLesson.day.toString().padLeft(2, '0');
        final month = nextLesson.month.toString().padLeft(2, '0');
        nextLessonText = '$weekday, $day.$month.${nextLesson.year} um $time';
      }
    }

    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Fach löschen'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Möchtest du das Fach '),
                        TextSpan(
                          text: subject.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(text: ' wirklich löschen?'),
                      ],
                    ),
                  ),
                  if (subject.nextLesson != null) ...[
                    standardGap(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.event, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Nächste Unterrichtsstunde:',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4),
                              Text(nextLessonText),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Abbrechen'),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Löschen'),
                ),
              ],
              elevation: 4,
            );
          },
        ) ??
        false;
  }

  Widget _buildItem(
    BuildContext context,
    Subject subject,
    int index,
    Animation<double> animation,
  ) {
    subject.backColor.harmonizeWith(Theme.of(context).primaryColor);
    bool isLoading = _isProcessing[subject.id] ?? false;
    return SizeTransition(
      sizeFactor: animation,
      alignment: Alignment.topLeft,
      child: ScaleTransition(
        scale: animation,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SubjectTile(
            subject: subject,
            trailing: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: switch (widget.subjectListType) {
                      SubjectListType.inUnitsButNotInFirestore => const Icon(
                        Icons.add_circle_outline,
                      ),
                      SubjectListType.inFirestoreButNotInUntis => const Icon(
                        Icons.delete_outline,
                      ),
                      SubjectListType.inBoth ||
                      SubjectListType.inFirestoreUntisNotAvailable => Icon(
                        subject.visible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    },
                    onPressed: () async {
                      final currentSubject = _subjects[index];
                      if (widget.subjectListType ==
                          SubjectListType.inUnitsButNotInFirestore) {
                        // Importieren erfordert keine Bestätigung
                        _handleImport(currentSubject, index);
                      } else if (widget.subjectListType ==
                          SubjectListType.inFirestoreButNotInUntis) {
                        // Beim Löschen Bestätigungsdialog anzeigen
                        bool confirm = await _showConfirmationDialog(
                          currentSubject,
                        );
                        if (confirm && mounted) {
                          _handleRemove(currentSubject, index);
                        }
                      } else {
                        _handleVisibilityToggle(currentSubject, index);
                      }
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildRemovedItem(Subject subject, Animation<double> animation) {
    subject.backColor.harmonizeWith(Theme.of(context).primaryColor);
    return SizeTransition(
      sizeFactor: animation,
      alignment: Alignment.topLeft,
      child: ScaleTransition(
        scale: animation,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SubjectTile(subject: subject),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        littleGap(),
        // Titel mit Schließen-Button
        ListTile(
          title: Text(
            widget.title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),

        // Aktionsbereich für Massenaktionen (Alle importieren/entfernen)
        // Nur anzeigen, wenn es Fächer gibt UND der Typ nicht "inBothFirestoreAndUntis" ist
        if (_subjects.isNotEmpty &&
            widget.subjectListType != SubjectListType.inBoth &&
            widget.subjectListType !=
                SubjectListType.inFirestoreUntisNotAvailable)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 4.0,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: .5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    "${_subjects.length} ${_subjects.length == 1 ? 'Fach' : 'Fächer'} in der Liste",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  // "Alle importieren"-Button für Untis → Firebase
                  if (widget.subjectListType ==
                      SubjectListType.inUnitsButNotInFirestore)
                    ElevatedButton.icon(
                      onPressed: _isProcessing.isNotEmpty
                          ? null
                          : _importAllSubjects,
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Alle importieren'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        minimumSize: const Size(40, 36),
                      ),
                    ),
                  // "Alle entfernen"-Button für Firebase-Fächer
                  if (widget.subjectListType ==
                      SubjectListType.inFirestoreButNotInUntis)
                    ElevatedButton.icon(
                      onPressed: _isProcessing.isNotEmpty
                          ? null
                          : _removeAllSubjects,
                      icon: const Icon(Icons.delete_sweep, size: 18),
                      label: const Text('Alle entfernen'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        minimumSize: const Size(40, 36),
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                      ),
                    ),
                ],
              ),
            ),
          ),

        if (_subjects.isEmpty && _isProcessing.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.subjectListType ==
                            SubjectListType.inUnitsButNotInFirestore
                        ? Icons.school_outlined
                        : Icons.book_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Keine Fächer in dieser Liste',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: AnimatedList(
                key: widget.listKey,
                initialItemCount: _subjects.length,
                shrinkWrap: true,
                itemBuilder: (context, index, animation) {
                  if (index >= _subjects.length) {
                    return const SizedBox.shrink();
                  }
                  final subject = _subjects[index];
                  return _buildItem(context, subject, index, animation);
                },
              ),
            ),
          ),

        // Abstand am unteren Rand
        littleGap(),
      ],
    );
  }
}
