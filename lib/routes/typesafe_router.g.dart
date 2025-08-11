// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'typesafe_router.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [
      $authRoute,
      $navigationShellRoute,
    ];

RouteBase get $authRoute => GoRouteData.$route(
      path: '/auth',
      factory: _$AuthRoute._fromState,
    );

mixin _$AuthRoute on GoRouteData {
  static AuthRoute _fromState(GoRouterState state) => const AuthRoute();

  @override
  String get location => GoRouteData.$location(
        '/auth',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $navigationShellRoute => ShellRouteData.$route(
      factory: $NavigationShellRouteExtension._fromState,
      routes: [
        GoRouteData.$route(
          path: '/home',
          factory: _$HomeRoute._fromState,
          routes: [
            GoRouteData.$route(
              path: 'createHomework',
              factory: _$CreateHomeworkRoute._fromState,
            ),
            GoRouteData.$route(
              path: 'subjectSelection',
              factory: _$SubjectSelectionRoute._fromState,
            ),
          ],
        ),
        GoRouteData.$route(
          path: '/untis',
          factory: _$UntisRoute._fromState,
          routes: [
            GoRouteData.$route(
              path: 'enterCredentials',
              factory: _$EnterCredentialsRoute._fromState,
            ),
            GoRouteData.$route(
              path: 'uploadCredentials',
              factory: _$UploadCredentialsRoute._fromState,
            ),
            GoRouteData.$route(
              path: 'downloadCredentials',
              factory: _$DownloadCredentialsRoute._fromState,
            ),
          ],
        ),
        GoRouteData.$route(
          path: '/account',
          factory: _$AccountRoute._fromState,
        ),
      ],
    );

extension $NavigationShellRouteExtension on NavigationShellRoute {
  static NavigationShellRoute _fromState(GoRouterState state) =>
      const NavigationShellRoute();
}

mixin _$HomeRoute on GoRouteData {
  static HomeRoute _fromState(GoRouterState state) => const HomeRoute();

  @override
  String get location => GoRouteData.$location(
        '/home',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$CreateHomeworkRoute on GoRouteData {
  static CreateHomeworkRoute _fromState(GoRouterState state) =>
      const CreateHomeworkRoute();

  @override
  String get location => GoRouteData.$location(
        '/home/createHomework',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$SubjectSelectionRoute on GoRouteData {
  static SubjectSelectionRoute _fromState(GoRouterState state) =>
      SubjectSelectionRoute(
        $extra: state.extra as void Function(Subject),
      );

  SubjectSelectionRoute get _self => this as SubjectSelectionRoute;

  @override
  String get location => GoRouteData.$location(
        '/home/subjectSelection',
      );

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}

mixin _$UntisRoute on GoRouteData {
  static UntisRoute _fromState(GoRouterState state) => const UntisRoute();

  @override
  String get location => GoRouteData.$location(
        '/untis',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$EnterCredentialsRoute on GoRouteData {
  static EnterCredentialsRoute _fromState(GoRouterState state) =>
      const EnterCredentialsRoute();

  @override
  String get location => GoRouteData.$location(
        '/untis/enterCredentials',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$UploadCredentialsRoute on GoRouteData {
  static UploadCredentialsRoute _fromState(GoRouterState state) =>
      const UploadCredentialsRoute();

  @override
  String get location => GoRouteData.$location(
        '/untis/uploadCredentials',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$DownloadCredentialsRoute on GoRouteData {
  static DownloadCredentialsRoute _fromState(GoRouterState state) =>
      const DownloadCredentialsRoute();

  @override
  String get location => GoRouteData.$location(
        '/untis/downloadCredentials',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$AccountRoute on GoRouteData {
  static AccountRoute _fromState(GoRouterState state) => const AccountRoute();

  @override
  String get location => GoRouteData.$location(
        '/account',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}
