import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../database/models/homework.dart';
import '../../database/models/subject.dart';
import '../../provider/homeworks_provider.dart';
import '../../provider/untis_provider.dart';
import '../../routes/typesafe_router.dart';
import '../../utilities/global_snackbar.dart';
import '../../widgets/fab.dart';
import '../../widgets/subject_tile.dart';

/// Defines the type of homework created.
/// [homework] → normal task
/// [exam] → exam or test
enum HomeworkType { homework, exam }

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
  const CreateHomework({super.key});

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
  DateTime dueDate = DateTime.now().add(const Duration(days: 1));

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    /// Automatically suggest the current lesson’s subject if none selected
    Subject? currentSubject =
    context.watch<UntisProvider>().getCurrentSubject();

    if (currentSubject != null &&
        (selectedSubject == null || selectedSubject == lastCurrentSubject)) {
      _updateSubject(currentSubject);
    }

    lastCurrentSubject ??= currentSubject;

    // If no subject → automatic next-lesson mode disabled
    if (selectedSubject == null) {
      toNextLesson = false;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hinzufügen'),
        elevation: 0,
      ),
      body: Padding(
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
                _buildDetails(),
                buildFABGap()
              ],
            ),
          ),
        ),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      /// Save button
      floatingActionButton: ExtendedFAB(
        icon: Icons.save,
        label: 'Hausaufgabe hinzufügen',
        onClick: _submit,
        active: true,
      ),
    );
  }

  /// Validates UI → Creates a [Homework] → Saves via [HomeworksProvider]
  void _submit() {
    if (_formKey.currentState!.validate()) {
      // Subject required
      if (selectedSubject == null) {
        showSnackBar('Bitte wähle ein Fach aus');
        return;
      }

      /// Construct homework object
      Homework homework = Homework(
        title: _titleController.text,
        description: _descriptionController.text,
        subjectDocId: selectedSubject!.documentId,
        toNextLesson: toNextLesson,
        isCompleted: false,
        dueDate: dueDate,
        fromUntis: false,
        isExam: selected == HomeworkType.exam,
      );

      // Save the homework
      context.read<HomeworksProvider>().createHomework(homework);
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
      initialDate: dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Fälligkeitsdatum wählen',
      cancelText: 'Abbrechen',
      confirmText: 'Bestätigen',
      locale: const Locale('de', 'DE'),
    );

    if (picked != null && picked != dueDate) {
      setState(() {
        dueDate = picked;
        toNextLesson = false; // Auto next-lesson disabled manually
      });
    }
  }

  /// Homework description input
  TextFormField _buildDetails() {
    return TextFormField(
      controller: _descriptionController,
      decoration: const InputDecoration(
        hintText: 'Beschreibung eingeben...',
      ),
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
          children: [
            Text(
              '${dueDate.day}.${dueDate.month}.${dueDate.year}',
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
  SwitchListTile _buildNextLessonSwitch(BuildContext context) {
    return SwitchListTile(
      title: const Text('Bis zur nächsten Stunde'),
      value: toNextLesson,
      onChanged: (value) async {
        if (selectedSubject == null || selected == HomeworkType.exam) {
          return; // Disabled for exam/no subject
        }
        setState(() {
          toNextLesson = value;
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

        // Navigation handled via GoRouter; callback passed via $extra
        onTap: () =>
            SubjectSelectionRoute($extra: _updateSubject).push(context),
      )
          : SubjectTileTemplate(
        title: 'Fach bitte wählen',
        avatarChild: const Icon(
          Icons.question_mark,
          color: Colors.grey,
        ),
        trailing: const Icon(Icons.arrow_drop_down),
        backColor: Colors.grey.shade200,
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
        segments: const [
          ButtonSegment<HomeworkType>(
            value: HomeworkType.homework,
            label: Text('Hausaufgabe'),
          ),
          ButtonSegment<HomeworkType>(
            value: HomeworkType.exam,
            label: Text('Test'),
          ),
        ],
        selected: {selected},
        onSelectionChanged: (Set<HomeworkType> newSelection) {
          setState(() {
            if (newSelection.contains(HomeworkType.exam)) {
              toNextLesson = false;
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
}
