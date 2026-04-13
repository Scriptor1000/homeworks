import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
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

/// Layout constants controlling spacing and border sizes for urgent homework UI
const urgentContainerMargin = 12.0;
const urgentContainerPadding = 8.0;
const urgentContainerBorderWidth = 3.0;

/// Combined padding value used for positioning homeworks UI sections
const horizontalPadding =
    urgentContainerMargin + urgentContainerPadding + urgentContainerBorderWidth;

/// The main screen that displays all existing homeworks & exams.
/// It also provides fast creation, detailed creation navigation,
/// and groups items into categories such as urgent and no due date.
class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  /// Allows entering "quick add" text for homework
  final TextEditingController _textController = TextEditingController();

  /// Used to detect focus for layout/animation behavior
  final FocusNode _textFocus = FocusNode();

  /// True when the quick-add textbox is focused
  bool focused = false;

  @override
  void dispose() {
    _textController.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    /// Listen for focus changes so UI can animate the FAB
    _textFocus.addListener(() {
      setState(() {
        focused = _textFocus.hasFocus;
      });
    });
    super.initState();
  }

  /// If text was typed -> fast create homework.
  /// Otherwise -> open full CreateHomework page.
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
    /// Reads homework data from provider so UI stays updated
    final homeworkProvider = context.watch<HomeworksProvider>();

    /// Separate homework into categories for UI presentation
    final urgentHomeworks = homeworkProvider.homeworks.urgent;
    final nonUrgentHomeworks = homeworkProvider.homeworks.notUrgent.withDueDate;
    final poorlyHomeworks = homeworkProvider.homeworks.withoutDueDate;

    /// Sort urgent & non-urgent homeworks chronologically
    urgentHomeworks.sort(
          (a, b) => a.dueDate!.compareTo(b.dueDate!),
    );
    nonUrgentHomeworks.sort(
          (a, b) => a.dueDate!.compareTo(b.dueDate!),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hausaufgaben'),
        /*actions: [
          IconButton(
            iconSize: 32,
            icon: const Icon(Icons.swap_horiz),
            onPressed: () {
              const TimetableRoute().go(context);
            },
          ),
        ],*/
      ),

      /// Show spinner until initial homework load completes
      body: !homeworkProvider.homeworksLoaded
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            /// Urgent section
            if (urgentHomeworks.isNotEmpty)
              buildUrgentHomeworks(context, urgentHomeworks),

            /// Normal due-date homework section
            Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: horizontalPadding),
                child: buildHomeworks(nonUrgentHomeworks)),

            /// Items without due date
            if (poorlyHomeworks.isNotEmpty)
              buildPoorlyHomeworks(context, poorlyHomeworks),

            buildFABGap()
          ],
        ),
      ),

      /// Adds a FAB row with quick add text field + button
      floatingActionButton: buildFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  /// Called when homework is marked done; currently logs only
  void onCompleted(int index) {
    print('Homework at index $index completed');
  }

  /// Builds the "urgent" decorated section
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
      ),
    );
  }

  /// Builds "no due date" decorated section
  Widget buildPoorlyHomeworks(
      BuildContext context, List<Homework> poorlyHomeworks) {
    return buildDecoratedHomeworks(
        context: context,
        borderColor: Colors.grey,
        label: 'Ohne Abgabedatum',
        child: buildHomeworks(poorlyHomeworks));
  }

  /// Adds border, padding + label for homework category sections
  Widget buildDecoratedHomeworks({
    required BuildContext context,
    required Color borderColor,
    required String label,
    required Widget child,
  }) {
    return Stack(
      children: [
        /// Main bordered container
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

        /// Positioned category label floating over the border
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
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: borderColor),
            ),
          ),
        ),
      ],
    );
  }

  /// Renders a list of homework tiles (not scrollable by itself)
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
            onCompleted: () {
              onCompleted(index);
            },
          ),
        );
      },
    );
  }

  /// Floating input bar to quickly add homework
  /// → includes text field + animated FAB
  Widget buildFAB() {
    Duration duration = const Duration(milliseconds: 300);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          /// Type here to quickly add
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

          /// Animated add button that shrinks/expands when textfield focused
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

  /// Creates a quick homework entry using the currently active subject (if any)
  Future<void> fastCreate() async {
    final untisProvider = context.read<UntisProvider>();
    var currentSubjectID = untisProvider.getCurrentSubject();

    if (currentSubjectID == null) {
      // This is pushed because it should not be showed in the URL
      // and it should always navigate back to this page.
      SubjectSelectionRoute($extra: onSubjectForFastCreate).push(context);
    } else {
      final homeworkProvider = context.read<HomeworksProvider>();
      final currentSubject = subjectProvider.getSubjectByUntisId(
        currentSubjectID,
      );
      if (currentSubject == null) {
        Sentry.logger.warn(
          'No subject found for current subject ID: ${currentSubjectID.id}',
        );
        SubjectSelectionRoute($extra: onSubjectForFastCreate).push(context);
      } else {
        if (currentSubject.visible == false) {
          showSnackBar(
            'Das erkannte aktuelle Fach ist ausgeblendet, es wurde trotzdem verwendet.',
          );
        }
        await homeworkProvider.fastCreateHomework(
          _textController.text,
          currentSubject,
        );
        _textController.clear();
      }
    }
  }

  /// Callback for subject selection after fast create
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
