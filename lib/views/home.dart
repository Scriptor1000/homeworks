import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../database/models/homework.dart';
import '../database/models/subject.dart';
import '../provider/homeworks_provider.dart';
import '../provider/subject_provider.dart';
import '../provider/untis_provider.dart';
import '../routes/typesafe_router.dart';
import '../utilities/constants.dart';
import '../utilities/global_snackbar.dart';
import '../utilities/homeworks_list.dart';
import '../widgets/fab.dart';
import '../widgets/homework_tile.dart';
import 'home/create_homework.dart';

const urgentContainerMargin = 12.0;
const urgentContainerPadding = 8.0;
const urgentContainerBorderWidth = 3.0;

const horizontalPadding =
    urgentContainerMargin + urgentContainerPadding + urgentContainerBorderWidth;

/// The main view wich shows the homeworks and exams.
/// It also provides a quick way to add new homeworks or to open [CreateHomework].
class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocus = FocusNode();

  bool focused = false;

  @override
  void dispose() {
    _textController.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    _textFocus.addListener(() {
      setState(() {
        focused = _textFocus.hasFocus;
      });
    });
    super.initState();
  }

  void _handleAddAction() {
    final text = _textController.text;
    if (text.isNotEmpty) {
      fastCreate();
    } else {
      // Navigiere zur CreateHomework-Seite
      const CreateHomeworkRoute().go(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeworkProvider = context.watch<HomeworksProvider>();

    final urgentHomeworks = homeworkProvider.homeworks.urgent;
    final nonUrgentHomeworks = homeworkProvider.homeworks.notUrgent.withDueDate;
    final poorlyHomeworks = homeworkProvider.homeworks.withoutDueDate;

    urgentHomeworks.sort(
      (a, b) => a.dueDate!.compareTo(b.dueDate!),
    );
    nonUrgentHomeworks.sort(
      (a, b) => a.dueDate!.compareTo(b.dueDate!),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hausaufgaben'),
      ),
      body: !homeworkProvider.homeworksLoaded
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  if (urgentHomeworks.isNotEmpty)
                    buildUrgentHomeworks(context, urgentHomeworks),
                  Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: horizontalPadding),
                      child: buildHomeworks(nonUrgentHomeworks)),
                  if (poorlyHomeworks.isNotEmpty)
                    buildPoorlyHomeworks(context, poorlyHomeworks),
                  buildFABGap()
                ],
              ),
            ),
      floatingActionButton: buildFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void statusChange(int index) {
    // this is just for possible future animations, etc.
  }

  Widget buildUrgentHomeworks(BuildContext context, Homeworks urgentHomeworks) {
    return buildDecoratedHomeworks(
        context: context,
        borderColor: Theme.of(context).colorScheme.primary,
        label: 'Dringlich!',
        child: Column(
          children: [
            buildHomeworks(urgentHomeworks.notCompleted),
            buildHomeworks(urgentHomeworks.completed),
          ],
        ));
  }

  Widget buildPoorlyHomeworks(
      BuildContext context, List<Homework> poorlyHomeworks) {
    return buildDecoratedHomeworks(
        context: context,
        borderColor: Colors.grey,
        label: 'Ohne Abgabedatum',
        child: buildHomeworks(poorlyHomeworks));
  }

  Widget buildDecoratedHomeworks(
      {required BuildContext context,
      required Color borderColor,
      required String label,
      required Widget child}) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(
              horizontal: urgentContainerMargin, vertical: 8),
          padding: const EdgeInsets.all(urgentContainerPadding),
          decoration: BoxDecoration(
            border: Border.all(
              color: borderColor,
              width: urgentContainerBorderWidth,
            ),
            borderRadius:
                BorderRadius.circular(BorderRadiusConstants.homeworks),
          ),
          child: child,
        ),
        Positioned(
          left: 20,
          top: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            margin: EdgeInsets.zero,
            height: 19,
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: borderColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildHomeworks(List<Homework> homeworks) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: homeworks.length,
      itemBuilder: (context, index) {
        final homework = homeworks[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: HomeworkTile(
            homework: homework,
            statusChange: () {
              statusChange(index);
            },
          ),
        );
      },
    );
  }

  Widget buildFAB() {
    Duration duration = const Duration(milliseconds: 300);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _textFocus,
              onTapOutside: (_) {
                _textFocus.unfocus();
              },
              onSubmitted: (_) {
                _handleAddAction();
              },
              onEditingComplete: () {
                _textFocus.unfocus();
              },
              decoration: InputDecoration(
                  hintText: 'Schnell hinzufügen...',
                  fillColor: Theme.of(context).colorScheme.surface,
                  filled: true),
            ),
          ),
          AnimatedPadding(
            duration: duration,
            padding:
                EdgeInsets.only(left: focused ? 10 : 2 * horizontalPadding),
            child: AnimatedScale(
              alignment: Alignment.centerRight,
              duration: duration,
              scale: focused ? 1 : 1.2,
              child: FloatingActionButton(
                onPressed: _handleAddAction,
                tooltip: 'Hinzufügen',
                child: const Icon(Icons.add),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> fastCreate() async {
    final untisProvider = context.read<UntisProvider>();
    final currentSubjectID = untisProvider.getCurrentSubject();

    if (currentSubjectID == null) {
      // This is pushed because it should not be shown in the URL
      // and it should always navigate back to this page.
      SubjectSelectionRoute($extra: onSubjectForFastCreate).push(context);
    } else {
      final subjectProvider = context.read<SubjectProvider>();
      final homeworkProvider = context.read<HomeworksProvider>();
      final currentSubject =
          subjectProvider.getSubjectByUntisId(currentSubjectID);
      if (currentSubject == null) {
        Sentry.logger.warn(
            'No subject found for current subject ID: ${currentSubjectID.id}');
        SubjectSelectionRoute($extra: onSubjectForFastCreate).push(context);
      } else {
        if (currentSubject.visible == false) {
          showSnackBar(
              'Das erkannte aktuelle Fach ist ausgeblendet, es wurde trotzdem verwendet.');
        }
        await homeworkProvider.fastCreateHomework(
            _textController.text, currentSubject);
        _textController.clear();
      }
    }
  }

  void onSubjectForFastCreate(Subject? subject) async {
    if (subject == null) {
      showSnackBar('Es wurde kein Fach erkannt, du musst eines auswählen.');
    } else {
      final homeworkProvider = context.read<HomeworksProvider>();
      await homeworkProvider.fastCreateHomework(_textController.text, subject);
      _textController.clear();
    }
  }
}
