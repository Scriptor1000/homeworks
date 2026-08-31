import 'package:flutter/material.dart';

import '../database/models/homework.dart';
import '../utilities/constants.dart';
import 'fab.dart';
import 'homework_tile.dart';

/// Renders a list of homework tiles (not scrollable by itself)
class HomeworksList extends StatelessWidget {
  final ValueChanged<int> onCompleted;
  final List<Homework> homeworks;
  final bool withDateInfo;
  final ({
    double containerMargin,
    double containerPadding,
    double containerBorderWidth,
    String label,
    Color borderColor,
  })?
  decoration;

  const HomeworksList({
    super.key,
    required this.onCompleted,
    required this.homeworks,
    this.decoration,
    this.withDateInfo = false,
  });

  @override
  Widget build(BuildContext context) {
    return _buildDecoration(context, _buildList());
  }

  /// Adds border, padding + label for homework category sections
  Widget _buildDecoration(BuildContext context, Widget child) {
    if (decoration == null) {
      return child;
    }
    return Stack(
      children: [
        /// Main bordered container
        Container(
          margin: EdgeInsets.symmetric(
            horizontal: decoration!.containerMargin,
            vertical: 8,
          ),
          padding: EdgeInsets.all(decoration!.containerPadding),
          decoration: BoxDecoration(
            border: Border.all(
              color: decoration!.borderColor,
              width: decoration!.containerBorderWidth,
            ),
            borderRadius: BorderRadius.circular(
              BorderRadiusConstants.homeworks,
            ),
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
              decoration!.label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: decoration!.borderColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: homeworks.length,
      itemBuilder: (context, index) {
        final homework = homeworks[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: kGapSize / 2),
          child: HomeworkTile(
            withDateInfo: withDateInfo,
            homework: homework,
            statusChange: () {
              onCompleted(index);
            },
          ),
        );
      },
    );
  }
}
