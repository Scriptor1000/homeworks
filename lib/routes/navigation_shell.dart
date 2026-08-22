import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'typesafe_router.dart';

/// A shell widget that displays a bottom navigation bar across all routes.
///
/// The [child] is the current screen displayed above the navigation bar.
/// The [state] is the current GoRouter state, used to determine the selected index.
class NavigationShell extends StatelessWidget {
  const NavigationShell({super.key, required this.child, required this.state});

  /// The screen to display above the bottom navigation bar.
  final Widget child;

  /// The current GoRouter state, used to highlight the correct navigation item.
  final GoRouterState state;

  @override
  Widget build(BuildContext context) {
    int maxWidth = 600; // Define the maximum width for the layout

    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth > maxWidth
          ? _buildLargeLayout(context)
          : _buildSmallLayout(context),
    );
  }

  Widget _buildSmallLayout(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: DestinationsManager.getNavigationIndex(state),
        onDestinationSelected: (index) {
          _onItemTapped(index, context);
        },
        destinations: DestinationsManager.bottomNavigationDestinations,
      ),
    );
  }

  Widget _buildLargeLayout(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: DestinationsManager.getNavigationIndex(state),
            onDestinationSelected: (index) {
              _onItemTapped(index, context);
            },
            labelType: NavigationRailLabelType.all,
            destinations: DestinationsManager.navigationRailDestinations,
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }

  /// Handles taps on the bottom navigation items.
  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      /*case 0:
        const TimetableRoute().go(context);
        break;*/
      case 0:
        const HomeRoute().go(context);
        break;
      case 1:
        const UntisRoute().go(context);
        break;
      case 2:
        const AccountRoute().go(context);
        break;
      default:
        const HomeRoute().go(context);
    }
  }
}
