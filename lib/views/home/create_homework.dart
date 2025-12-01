import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../database/models/homework.dart';
import '../../database/models/subject.dart';
import '../../provider/homeworks_provider.dart';
import '../../provider/subject_provider.dart';
import '../../provider/untis_provider.dart';
import '../../routes/typesafe_router.dart';
import '../../utilities/enums.dart';
import '../../utilities/global_snackbar.dart';
import '../../widgets/fab.dart';
import '../../widgets/subject_tile.dart';

/// A widget for creating a [Homework] with all available Options.
class CreateHomework extends StatefulWidget {
  const CreateHomework({super.key});

  @override
  State<CreateHomework> createState() => _CreateHomeworkState();
}

class _CreateHomeworkState extends State<CreateHomework> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  HomeworkType selected = HomeworkType.homework;
  Subject? selectedSubject;
  Subject? lastCurrentSubject;
  bool toNextLesson = true;
  DateTime dueDate = DateTime.now().add(const Duration(days: 1));

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentSubjectID = context.watch<UntisProvider>().getCurrentSubject();
    Subject? currentSubject;
    if (currentSubjectID != null) {
      currentSubject =
          context.read<SubjectProvider>().getSubjectByUntisId(currentSubjectID);
    }

    if (currentSubject != null &&
        (selectedSubject == null || selectedSubject == lastCurrentSubject)) {
      _updateSubject(currentSubject);
    }
    lastCurrentSubject ??= currentSubject;
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
                _buildTime(context),
                standardGap(),
                _buildDetails(),
                buildFABGap()
              ],
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: ExtendedFAB(
        icon: Icons.save,
        label: 'Hausaufgabe hinzufügen',
        onClick: _submit,
        active: true,
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (selectedSubject == null) {
        showSnackBar('Bitte wähle ein Fach aus');
        return;
      }
      Homework homework = Homework(
        title: _titleController.text,
        description: _descriptionController.text,
        subjectDocId: selectedSubject!.documentId,
        toNextLesson: toNextLesson,
        isCompleted: false,
        dueDate: dueDate,
        fromUntis: false,
        type: selected,
      );

      // Save the homework
      context.read<HomeworksProvider>().createHomework(homework);
      context.pop();
    }
  }

  void _updateSubject(Subject subject) {
    setState(() {
      selectedSubject = subject;
    });
    _findNextLesson();
  }

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

  Future<void> _showDatePicker() async {
    DateTime? picked = await showDatePicker(
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
        // The time in dueDate is used to determine if the homework can be deleted.
        // It is set to 18:00 here, so it is not automatically deleted too early in the day.
        dueDate = picked.add(toNextLesson
            ? const Duration(hours: 18)
            : Duration(
                // keep the time on date change
                hours: dueDate.hour,
                minutes: dueDate.minute,
              ));
        toNextLesson = false;
      });
    }
  }

  TextFormField _buildDetails() {
    return TextFormField(
      controller: _descriptionController,
      decoration: const InputDecoration(
        hintText: 'Beschreibung eingeben...',
      ),
      maxLines: 5,
    );
  }

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

  void _showTimePicker() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: dueDate.hour, minute: dueDate.minute),
      helpText: 'Uhrzeit wählen',
      cancelText: 'Abbrechen',
      confirmText: 'Bestätigen',
    );

    if (picked != null) {
      setState(() {
        dueDate = DateTime(
          dueDate.year,
          dueDate.month,
          dueDate.day,
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
              '${dueDate.hour.toString().padLeft(2, '0')}:${dueDate.minute.toString().padLeft(2, '0')}',
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
        if (selectedSubject == null || selected == HomeworkType.exam) {
          return; // has to be false if no subject is selected or if it is an exam
        }
        setState(() {
          toNextLesson = value;
        });
        _findNextLesson();
      },
    );
  }

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
              avatarChild: const Icon(
                Icons.question_mark,
                color: Colors.grey,
              ),
              trailing: const Icon(Icons.arrow_drop_down),
              // TODO responsive color
              backColor: Colors.grey.shade200,
              // see above
              onTap: () =>
                  SubjectSelectionRoute($extra: _updateSubject).push(context)),
    );
  }

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
        // autofocus: true,
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
