import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:dart_untis_mobile/dart_untis_mobile.dart';

import '../../database/models/homework.dart';
import '../../database/models/subject.dart';
import '../../provider/homeworks_provider.dart';
import '../../provider/untis_provider.dart';
import '../../routes/typesafe_router.dart';
import '../../utilities/common.dart';
import '../../utilities/enums.dart';
import '../../utilities/global_snackbar.dart';
import '../../widgets/fab.dart';
import '../../widgets/subject_tile.dart';
import '../../provider/subject_provider.dart';

/// Defines the type of homework created.
/// [homework] → normal task
/// [exam] → exam or test

/// Page for creating and saving a new [Homework].
///
/// Features:
/// - Select subject
/// - Define title, description, due date
/// - Optional: auto-set due date to next lesson
/// - Can mark as homework or exam
///
/// Created Homework is stored using [HomeworksProvider].
class CreateHomework extends StatefulWidget {
  final Homework? existingHomework;
  const CreateHomework({super.key, this.existingHomework});

  @override
  State<CreateHomework> createState() => _CreateHomeworkState();
}

class _CreateHomeworkState extends State<CreateHomework> {
  /// Validation wrapper for inputs
  final _formKey = GlobalKey<FormState>();

  /// Text input for main title
  final _titleController = TextEditingController();

  /// Text input for optional description
  final _descriptionController = TextEditingController();

  /// Type selection (homework or exam)
  HomeworkType selected = HomeworkType.homework;

  /// Currently selected subject
  Subject? selectedSubject;

  /// Last auto-detected subject from lesson system
  Subject? lastCurrentSubject;

  /// If true → due date syncs to next lesson when possible
  bool toNextLesson = true;

  /// The due date of the task
  DateTime? dueDate;

  /// The selected emoji for the homework, if any
  HomeworkEmoji? selectedEmoji;

  @override
  void initState() {
    super.initState();

    if (widget.existingHomework != null) {
      final hw = widget.existingHomework!;
      _titleController.text = hw.title;
      _descriptionController.text = hw.description;
      selected = hw.type;
      toNextLesson = hw.toNextLesson;
      selectedEmoji = hw.emoji;
      dueDate = hw.dueDate;

      /// Find the subject object from the provider
      final subject = context.read<SubjectProvider>().subjects;
      selectedSubject = subject.firstWhereOrNull(
        (s) => s.documentId == hw.subjectDocId,
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    /// Automatically suggest the current lesson’s subject if none selected
    UntisElementDescriptor? currentDescriptor = context
        .watch<UntisProvider>()
        .getCurrentSubject();
    Subject? currentSubject = currentDescriptor == null
        ? null
        : context.watch<SubjectProvider>().subjects.firstWhereOrNull(
            (s) => s.id == currentDescriptor.id,
          );

    if (currentSubject != null &&
        (selectedSubject == null || selectedSubject == lastCurrentSubject) &&
        currentSubject != lastCurrentSubject) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _updateSubject(currentSubject);
        lastCurrentSubject = currentSubject;
      });
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingHomework == null ? 'Hinzufügen' : 'Bearbeiten',
        ),
        elevation: 0,
      ),
      body: withConstrainedWidth(
        context,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleInput(context),
                  standardGap(),
                  _buildTypeInput(),
                  standardGap(),
                  _buildSubjectSelection(context),
                  standardGap(),
                  _buildNextLessonSwitch(context),
                  standardGap(),
                  _buildDate(context),
                  standardGap(),
                  _buildTime(context),
                  standardGap(),
                  _buildEmojiPicker(),
                  standardGap(),
                  _buildDetails(),
                  buildFABGap(),
                ],
              ),
            ),
          ),
        ),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      /// Save button
      floatingActionButton: ExtendedFAB(
        icon: Icons.save,
        label: widget.existingHomework == null
            ? 'Hausaufgabe hinzufügen'
            : 'Änderungen Speichern',
        onClick: _submit,
        active: true,
      ),
    );
  }

  /// Validates UI → Creates a [Homework] → Saves via [HomeworksProvider]
  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (selectedSubject == null) {
        showSnackBar('Bitte wähle ein Fach aus');
        return;
      }
      if (!toNextLesson && dueDate == null) {
        showSnackBar('Bitte ein Fälligkeitsdatum wählen');
        return;
      }

      Homework homework;

      if (widget.existingHomework != null) {
        homework = widget.existingHomework!;
        // Update existing homework
        homework.title = _titleController.text;
        homework.description = _descriptionController.text;
        homework.subjectDocId = selectedSubject!.documentId;
        homework.toNextLesson = toNextLesson;
        homework.dueDate = dueDate;
        homework.type = selected;
        homework.emoji = selectedEmoji;
        context.read<HomeworksProvider>().updateHomework(homework);
      } else {
        // Create new homework
        homework = Homework(
          title: _titleController.text,
          description: _descriptionController.text,
          subjectDocId: selectedSubject!.documentId,
          toNextLesson: toNextLesson,
          isCompleted: false,
          dueDate: dueDate,
          fromUntis: false,
          type: selected,
          emoji: selectedEmoji,
        );
        context.read<HomeworksProvider>().createHomework(homework);
      }
      context.pop();
    }
  }

  /// Set new selected subject and update due date
  void _updateSubject(Subject subject) {
    setState(() {
      selectedSubject = subject;
    });
    _findNextLesson();
  }

  /// Finds and sets next lesson date from selected subject
  void _findNextLesson() {
    if (selectedSubject == null || !toNextLesson) return;

    _getNextLessonDate().then((nextLesson) {
      if (nextLesson != null) {
        setState(() {
          toNextLesson = true;
          dueDate = nextLesson;
        });
      } else {
        setState(() {
          toNextLesson = false;
        });
      }
    });
  }

  /// Retrieves the next lesson date/time for the selected subject if available.
  ///
  /// Returns:
  /// - DateTime of next lesson
  /// - null if unavailable
  Future<DateTime?> _getNextLessonDate() async {
    if (selectedSubject == null || !toNextLesson) return null;

    if (selectedSubject!.nextLesson != null &&
        selectedSubject!.nextLesson!.isAfter(DateTime.now())) {
      return selectedSubject!.nextLesson!;
    } else {
      showSnackBar('Keine nächste Stunde gefunden');
      return null;
    }
  }

  /// Opens date picker → Manual date selection disables auto mode
  Future<void> _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: dueDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Fälligkeitsdatum wählen',
      cancelText: 'Abbrechen',
      confirmText: 'Bestätigen',
      locale: const Locale('de', 'DE'),
    );
    if (!mounted || picked == null) return;

    Duration? timeOfSubjectOnDay = selectedSubject != null
        ? context.read<UntisProvider>().getTimeOfSubjectOnDay(
            picked,
            selectedSubject!,
          )
        : null;

    if (picked != dueDate) {
      setState(() {
        // The time in dueDate is used to determine if the homework can be deleted.
        // It is set to 18:00 here, so it is not automatically deleted too early in the day.
        dueDate = picked.add(
          timeOfSubjectOnDay ??
              (toNextLesson
                  ? const Duration(hours: 18)
                  : Duration(
                      // keep the time on date change
                      hours: dueDate?.hour ?? 18,
                      minutes: dueDate?.minute ?? 0,
                    )),
        );
        toNextLesson = false;
      });
    }
  }

  /// Homework description input
  TextFormField _buildDetails() {
    return TextFormField(
      controller: _descriptionController,
      decoration: const InputDecoration(hintText: 'Beschreibung eingeben...'),
      maxLines: 5,
    );
  }

  /// Shows current due date + opens picker
  ListTile _buildDate(BuildContext context) {
    return ListTile(
      title: const Text('Fälligkeitsdatum'),

      trailing: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.primaryContainer,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dueDate != null
                  ? '${dueDate!.day}.${dueDate!.month}.${dueDate!.year}'
                  : 'Kein Datum',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            littleGap(),
            const Icon(Icons.calendar_today),
          ],
        ),
      ),

      onTap: _showDatePicker,
    );
  }

  /// Auto next-lesson toggle
  void _showTimePicker() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: dueDate?.hour ?? 18,
        minute: dueDate?.minute ?? 0,
      ),
      helpText: 'Uhrzeit wählen',
      cancelText: 'Abbrechen',
      confirmText: 'Bestätigen',
    );

    if (picked != null) {
      setState(() {
        final base = dueDate ?? DateTime.now().add(const Duration(days: 1));
        dueDate = DateTime(
          base.year,
          base.month,
          base.day,
          picked.hour,
          picked.minute,
        );
        toNextLesson = false;
      });
    }
  }

  ListTile _buildTime(BuildContext context) {
    return ListTile(
      title: const Text('Uhrzeit'),
      trailing: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.primaryContainer,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dueDate != null
                  ? '${dueDate!.hour.toString().padLeft(2, '0')}:${dueDate!.minute.toString().padLeft(2, '0')}'
                  : 'Keine Uhrzeit',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            littleGap(),
            const Icon(Icons.access_time_outlined),
          ],
        ),
      ),
      onTap: _showTimePicker,
    );
  }

  SwitchListTile _buildNextLessonSwitch(BuildContext context) {
    // TODO make safe:
    // subject must be from Untis
    // dueDate can only be null if nextLesson is true
    // don't forget to make the same requiremts to fast create
    return SwitchListTile(
      title: const Text('Bis zur nächsten Stunde'),
      value: toNextLesson,
      onChanged: (value) async {
        if (selectedSubject == null || selected != HomeworkType.homework) {
          return; // Disabled for exam/no subject
        }
        setState(() {
          toNextLesson = value;
          if (!value && dueDate == null) {
            dueDate = DateTime.now().add(const Duration(days: 1));
          }
        });
        _findNextLesson();
      },
    );
  }

  /// Subject picker → pushes subject selection route
  SizedBox _buildSubjectSelection(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: selectedSubject != null
          ? SubjectTile(
              subject: selectedSubject!,
              trailing: const Icon(Icons.arrow_drop_down),

              // This is pushed because it should not be showed in the URL
              // and it should always navigate back to this page.
              onTap: () =>
                  SubjectSelectionRoute($extra: _updateSubject).push(context),
            )
          : SubjectTileTemplate(
              title: 'Fach bitte wählen',
              avatarChild: const Icon(Icons.question_mark, color: Colors.grey),
              trailing: const Icon(Icons.arrow_drop_down),
              // TODO responsive color
              backColor: Colors.grey.shade200,
              // see above
              onTap: () =>
                  SubjectSelectionRoute($extra: _updateSubject).push(context),
            ),
    );
  }

  /// Type: homework vs exam
  SizedBox _buildTypeInput() {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<HomeworkType>(
        multiSelectionEnabled: false,
        showSelectedIcon: false,
        segments: const [
          ButtonSegment<HomeworkType>(
            value: HomeworkType.homework,
            label: Text('Hausaufgabe'),
          ),
          ButtonSegment<HomeworkType>(
            value: HomeworkType.exam,
            label: Text('Test'),
          ),
          ButtonSegment<HomeworkType>(
            value: HomeworkType.appointment,
            label: Text('Termin'),
          ),
        ],
        selected: {selected},
        onSelectionChanged: (Set<HomeworkType> newSelection) {
          setState(() {
            if (newSelection.contains(HomeworkType.exam)) {
              toNextLesson = false; // Exams should not have next lesson
            }
            selected = newSelection.first;
          });
        },
      ),
    );
  }

  /// Title input
  Container _buildTitleInput(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextFormField(
        controller: _titleController,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.all(20),
          hintText: 'Name',
          border: InputBorder.none,
        ),
        style: Theme.of(context).textTheme.titleLarge,
        textAlign: TextAlign.center,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Bitte gib einen Namen ein';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildEmojiPicker() {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<HomeworkEmoji>(
        emptySelectionAllowed: true,
        multiSelectionEnabled: false,
        showSelectedIcon: false,
        segments: HomeworkEmoji.values
            .map(
              (e) => ButtonSegment<HomeworkEmoji>(
                value: e,
                label: Text(e.emoji, style: const TextStyle(fontSize: 24)),
              ),
            )
            .toList(),
        selected: selectedEmoji == null ? {} : {selectedEmoji!},
        onSelectionChanged: (Set<HomeworkEmoji> newSelection) {
          setState(() {
            if (newSelection.isEmpty) {
              selectedEmoji = null;
              return;
            }
            selectedEmoji = newSelection.first;
          });
        },
      ),
    );
  }
}
