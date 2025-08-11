import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

const kFABHeight = 56.0;
const kGapSize = 16.0;

/// The Gap at the bottom of a ScrollView to make sure the FAB doesn't overlap with the content.
Widget buildFABGap() {
  return const Gap(
    kFABHeight + kGapSize,
  );
}

// The standard gap used in the app to seperate widgets.
Widget standardGap() {
  return const Gap(
    kGapSize,
  );
}

/// A smaller gap used in the app to create a little space between widgets.
Widget littleGap() {
  return const Gap(
    kGapSize / 2,
  );
}

/// Standardized Extended Floating Action Button (FAB) widget.
///
/// This widget has maxWidth and fixed height and margin and should always be used
/// instead of a [FloatingActionButton.extended] to unify the design.
class ExtendedFAB extends StatelessWidget {
  const ExtendedFAB(
      {super.key,
      required this.onClick,
      required this.active,
      required this.icon,
      required this.label});

  final VoidCallback onClick;
  final bool active;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        maxWidth: 400,
      ),
      height: kFABHeight,
      margin: const EdgeInsets.symmetric(horizontal: kGapSize),
      child: FloatingActionButton.extended(
        onPressed: active ? onClick : null,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}
