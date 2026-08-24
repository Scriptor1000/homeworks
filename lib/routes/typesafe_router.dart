import 'dart:async';

import 'package:animations/animations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dart_untis_mobile/dart_untis_mobile.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:provider/provider.dart';

import '../auth/login.dart';
import '../database/models/subject.dart';
import '../database/user.dart';
import '../views/account.dart';
import '../views/home.dart';
import '../views/home/create_homework.dart';
import '../views/home/subject_selection.dart';
import '../views/untis/find_teacher.dart';
import '../views/untis/load_credentials.dart';
import '../views/untis/untis_login.dart';
import '../views/untis/upload_credentials.dart';
import '../views/untis_view.dart';
//import '../views/timetable_view.dart';
import 'navigation_shell.dart';
import 'provider_shell.dart';
import '../provider/homeworks_provider.dart';
part 'typesafe_router.g.dart';

/// Stream that triggers GoRouter refresh when FirebaseAuth state changes
final _refreshStream =
    GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges());

/// Shortcut getters for route locations
//String get _timetableLocation => const TimetableRoute().location;
String get _homeLocation => const HomeRoute().location;
String get _untisLocation => const UntisRoute().location;
String get _accountLocation => const AccountRoute().location;
String get _authLocation => const AuthRoute().location;

/// Main app router using GoRouter

final appRouter = GoRouter(
  // Initial location depends on whether user is logged in
  initialLocation: FirebaseAuth.instance.currentUser == null
      ? _authLocation
      : _homeLocation,
  observers: [
    SentryNavigatorObserver(),
    FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
  ],
  refreshListenable: _refreshStream,
  redirect: (context, state) {
    final bool isLoggedIn = FirebaseAuth.instance.currentUser != null;
    final bool isOnAuth = state.matchedLocation == _authLocation;
    final bool isOnRoot = state.matchedLocation == '/';

    // Redirect to login if not logged in
    if (!isLoggedIn && !isOnAuth) {
      return _authLocation;
    }
    // Redirect logged in user away from login/root to home
    if (isLoggedIn && (isOnAuth || isOnRoot)) {
      return _homeLocation;
    }
    return null;
  },

  routes: $appRoutes,
);
/// Route for timetable demo page


/// Route for authentication screen
@TypedGoRoute<AuthRoute>(path: '/auth')
class AuthRoute extends GoRouteData with $AuthRoute {
  const AuthRoute();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: const Authentication(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SharedAxisTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          transitionType: SharedAxisTransitionType.horizontal,
          fillColor: Theme.of(context).scaffoldBackgroundColor,
          child: child,
        );
      },
    );
  }
}

/// Shell route for bottom navigation bar and nested navigation
@TypedShellRoute<NavigationShellRoute>(
  routes: <TypedRoute<RouteData>>[
    TypedGoRoute<HomeRoute>(
      path: '/home',
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<CreateHomeworkRoute>(path: 'createHomework'),
        TypedGoRoute<EditHomeworkRoute>(path: 'editHomework'),
        TypedGoRoute<SubjectSelectionRoute>(path: 'subjectSelection'),
      ],
    ),
    //TypedGoRoute<TimetableRoute>(path: '/timetable'),
    TypedGoRoute<UntisRoute>(
      path: '/untis',
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<EnterCredentialsRoute>(path: 'enterCredentials'),
        TypedGoRoute<UploadCredentialsRoute>(path: 'uploadCredentials'),
        TypedGoRoute<DownloadCredentialsRoute>(path: 'downloadCredentials'),
        TypedGoRoute<FindTeacherRoute>(path: 'findTeacher/:id'),
      ],
    ),
    TypedGoRoute<AccountRoute>(path: '/account'),
  ],
)
class NavigationShellRoute extends ShellRouteData {
  const NavigationShellRoute();

  @override
  Page pageBuilder(
    BuildContext context,
    GoRouterState state,
    Widget navigator,
  ) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Redirect to auth page if not logged in
      WidgetsBinding.instance.addPostFrameCallback((_) {
        GoRouter.of(context).go(_authLocation);
      });
      return NoTransitionPage(
        key: state.pageKey,
        child: Center(
          child: Text(
            'Du wirst zum Login weitergeleitet...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );
    }
    return CustomTransitionPage(
      key: state.pageKey,
      // Wrap child with ProviderShell for access to providers
      child: ProviderShell(
        uid: user.uid,
        child: NavigationShell(
          state: state,
          child: navigator,
        ),
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SharedAxisTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          transitionType: SharedAxisTransitionType.horizontal,
          fillColor: Theme.of(context).scaffoldBackgroundColor,
          child: child,
        );
      },
    );
  }
}

// Home Routes
class HomeRoute extends GoRouteData with $HomeRoute {
  const HomeRoute();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) {
    return NoTransitionPage(
      key: state.pageKey,
      child: const Home(),
    );
  }
}

class CreateHomeworkRoute extends GoRouteData with $CreateHomeworkRoute {
  const CreateHomeworkRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const CreateHomework();
  }
}

/*class TimetableRoute extends GoRouteData with $TimetableRoute {
  const TimetableRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const TimetableView();
  }
}*/

class EditHomeworkRoute extends GoRouteData with $EditHomeworkRoute {
  const EditHomeworkRoute({required this.homeworkId});

  final String homeworkId;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    // Fetch the Homework object from your provider
    final homework = context.read<HomeworksProvider>().getById(homeworkId);

    if (homework == null) {
      return Scaffold(
        body: Center(
          child: Text('Homework not found'),
        ),
      );
    }

    return CreateHomework(existingHomework: homework);
  }
}


class SubjectSelectionRoute extends GoRouteData with $SubjectSelectionRoute {
  /// Callback wich is called when a subject is selected.
  ///
  /// The callback receives the selected [Subject] or [Null]
  /// if the selection was closed without selecting.
  /// It has to be named [$extra] to satisfy the code generator.
  final void Function(Subject) $extra;

  const SubjectSelectionRoute({required this.$extra});

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return SubjectSelection(
      onSubjectSelected: $extra,
    );
  }

  @override
  FutureOr<String?> redirect(BuildContext context, GoRouterState state) {
    if (state.extra == null) {
      // If no subject is selected, redirect to the home page
      return const HomeRoute().location;
    }
    return null;
  }
}

// Untis Routes
class UntisRoute extends GoRouteData with $UntisRoute {
  const UntisRoute();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) {
    return NoTransitionPage(
      key: state.pageKey,
      child: const UntisView(),
    );
  }
}

class EnterCredentialsRoute extends GoRouteData with $EnterCredentialsRoute {
  const EnterCredentialsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const UntisLogin();
  }
}

class UploadCredentialsRoute extends GoRouteData with $UploadCredentialsRoute {
  const UploadCredentialsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const UploadCredentials();
  }
}

class DownloadCredentialsRoute extends GoRouteData
    with $DownloadCredentialsRoute {
  const DownloadCredentialsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const LoadCredentials();
  }
}

class FindTeacherRoute extends GoRouteData with $FindTeacherRoute {
  final int id;
  const FindTeacherRoute(this.id);

  @override
  Widget build(BuildContext context, GoRouterState state) {
    final descriptor = UntisElementDescriptor(.teacher, id);
    return FindTeacher(teacher: descriptor);
  }
}

// Account Route
class AccountRoute extends GoRouteData with $AccountRoute {
  const AccountRoute();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) {
    return NoTransitionPage(
      key: state.pageKey,
      child: const AccountView(),
    );
  }
}

/// A stream that listens to Firebase Auth state changes and notifies listeners
/// when the user logs in or out.
class GoRouterRefreshStream extends ChangeNotifier {
  bool _wasLoggedIn = false;

  GoRouterRefreshStream(Stream<User?> stream) {
    _subscription = stream.listen((user) async {
      if (user != null) {
        // Ensure user document exists in Firestore
        final firestoreUser = FirestoreUser(
          uid: user.uid,
          firestore: FirebaseFirestore.instance,
        );
        await firestoreUser.ensureDocumentExists();
        _wasLoggedIn = true;
        notifyListeners();
      } else if (_wasLoggedIn) {
        _wasLoggedIn = false;
        notifyListeners();
      }
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// A utility class for type-safe navigation in the app.
class DestinationsManager {
  /// Returns the index of the bottom navigation bar based on the current route.
  static int getNavigationIndex(GoRouterState state) {
    final location = state.matchedLocation;
    //if (location.startsWith(_timetableLocation)) return 0;
    if (location.startsWith(_homeLocation)) return 0;
    if (location.startsWith(_untisLocation)) return 1;
    if (location.startsWith(_accountLocation)) return 2;
    return 1;
  }

  /// Navigation destinations for bottom navigation bar
  static List<NavigationDestination> get bottomNavigationDestinations {
    return [
      /*const NavigationDestination(
        icon: Icon(Icons.edit_calendar_outlined),
        selectedIcon: Icon(Icons.edit_calendar),
        label: 'Timetable',
      ),*/
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Home',
      ),
      const NavigationDestination(
        icon: Icon(Icons.school_outlined),
        selectedIcon: Icon(Icons.school),
        label: 'Untis',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Konto',
      ),
    ];
  }
}
