import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:collection/collection.dart';

import '../database/models/homework.dart';
import '../database/models/subject.dart';
import '../provider/config_provider.dart';
import '../provider/homeworks_provider.dart';
import '../provider/subject_provider.dart';
import '../provider/untis_provider.dart';
import '../routes/typesafe_router.dart';
import '../utilities/common.dart';
import '../utilities/global_snackbar.dart';
import '../utilities/homeworks_list.dart';
import '../widgets/fab.dart';
import '../widgets/home_day_card.dart';
import '../widgets/homeworks_list.dart';

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
    final widthThreshold = context.select(
      (ConfigProvider p) => p.maxWidthThreshold,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Hausaufgaben')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return (constraints.maxWidth > widthThreshold)
              ? buildTabletScreen(context)
              : buildMobileScreen(context);
        },
      ),

      /// Adds a FAB row with quick add text field + button
      floatingActionButton: buildFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget buildTabletScreen(BuildContext context) {
    int dayCardCount = context.select((ConfigProvider p) => p.dayCardCount);
    bool hasFreeTime = context.select((UntisProvider p) => p.hasFreeTime);

    List<DateTime> upcomingWorkdays = [getNextWorkday(DateTime.now())];
    for (int i = 0; i < dayCardCount - 1; i++) {
      upcomingWorkdays.add(getNextWorkday(upcomingWorkdays[i]));
    }

    return ListView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.only(
        bottom:
            kFABHeight +
            MediaQuery.of(context).viewPadding.bottom +
            2 * kGapSize,
        left: horizontalPadding,
      ),
      children: [
        if (!hasFreeTime)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: HomeDayCard(date: DateTime.now()),
          ),
        ...upcomingWorkdays.map(
          (date) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: HomeDayCard(date: date),
          ),
        ),
      ],
    );
  }

  Widget buildMobileScreen(BuildContext context) {
    /// Reads homework data from provider so UI stays updated
    final homeworkProvider = context.watch<HomeworksProvider>();

    /// Separate homework into categories for UI presentation
    final urgentHomeworks = homeworkProvider.homeworks.urgent;
    final nonUrgentHomeworks = homeworkProvider.homeworks.notUrgent.withDueDate;
    final poorlyHomeworks = homeworkProvider.homeworks.withoutDueDate;

    /// Sort urgent & non-urgent homeworks chronologically
    urgentHomeworks.sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    nonUrgentHomeworks.sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

    /// Show spinner until initial homework load completes
    return !homeworkProvider.homeworksLoaded
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
                    horizontal: horizontalPadding,
                  ),
                  child: HomeworksList(
                    homeworks: nonUrgentHomeworks,
                    onCompleted: onCompleted,
                  ),
                ),

                /// Items without due date
                if (poorlyHomeworks.isNotEmpty)
                  buildPoorlyHomeworks(context, poorlyHomeworks),

                buildFABGap(),
              ],
            ),
          );
  }

  /// Called when homework is marked done; currently logs only
  void onCompleted(int index) {
    Sentry.logger.info('Homework at index $index completed');
  }

  /// Builds the "urgent" decorated section
  Widget buildUrgentHomeworks(BuildContext context, Homeworks urgentHomeworks) {
    return HomeworksList(
      homeworks: urgentHomeworks.notCompleted + urgentHomeworks.completed,
      onCompleted: onCompleted,
      decoration: (
        containerMargin: horizontalPadding,
        containerPadding: urgentContainerPadding,
        containerBorderWidth: urgentContainerBorderWidth,
        label: 'Dringlich!',
        borderColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  /// Builds "no due date" decorated section
  Widget buildPoorlyHomeworks(
    BuildContext context,
    List<Homework> poorlyHomeworks,
  ) {
    return HomeworksList(
      homeworks: poorlyHomeworks,
      onCompleted: onCompleted,
      decoration: (
        containerMargin: horizontalPadding,
        containerPadding: urgentContainerPadding,
        containerBorderWidth: urgentContainerBorderWidth,
        label: 'Ohne Abgabedatum',
        borderColor: Colors.grey,
      ),
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
                filled: true,
              ),
            ),
          ),

          /// Animated add button that shrinks/expands when textfield focused
          AnimatedPadding(
            duration: duration,
            padding: EdgeInsets.only(
              left: focused ? 10 : 2 * horizontalPadding,
            ),
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
      final currentSubject = context
          .read<SubjectProvider>()
          .subjects
          .firstWhereOrNull((s) => s.id == currentSubjectID.id);
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
