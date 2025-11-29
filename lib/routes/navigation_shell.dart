import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'typesafe_router.dart';

/// A shell widget wich displays the bottom navigation bar at all routes.
class NavigationShell extends StatelessWidget {
  const NavigationShell({super.key, required this.child, required this.state});

  /// The shown screen of the current route, shown above the bottom navigation bar.
  final Widget child;

  /// The current state of the GoRouter, used to determine the selected index.
  final GoRouterState state;

  @override
  Widget build(BuildContext context) {
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

  /// Handles the tap on a bottom navigation item.
  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
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
