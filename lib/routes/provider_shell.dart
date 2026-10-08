import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import '../database/credentials.dart';
import '../database/homeworks.dart';
import '../database/models/factory.dart';
import '../database/subjects.dart';
import '../database/user.dart';
import '../provider/config_provider.dart';
import '../provider/credential_provider.dart';
import '../provider/demo/credentials_demo_provider.dart';
import '../provider/demo/untis_demo_provider.dart';
import '../provider/homeworks_provider.dart';
import '../provider/subject_provider.dart';
import '../provider/sync_provider.dart';
import '../provider/untis_provider.dart';
import '../utilities/analytics_service.dart';
import '../utilities/cryptography.dart';

/// A shell widget that makes the providers available to all routes.
class ProviderShell extends StatelessWidget {
  final Widget child;
  final String uid;

  const ProviderShell({super.key, required this.child, required this.uid});

  @override
  Widget build(BuildContext context) {
    // Config provider for remote config
    final int untisTimetableLoadDays = context.select(
      (ConfigProvider p) => p.untisTimetableLoadDays,
    );
    final bool untisDemoMode = context.select(
      (ConfigProvider p) => p.untisDemoMode,
    );

    final firestore = FirebaseFirestore.instance;
    final analytics = FirebaseAnalytics.instance;
    final crashlytics = FirebaseCrashlytics.instance;
    final performance = FirebasePerformance.instance;
    // this could be a constant or config
    final range = Duration(days: untisTimetableLoadDays);

    // Cryptography utility for encrypting/decrypting credentials
    final cryptography = CredentialCryptography(uid: uid);
    // Factory to create data models
    final itemFactory = ItemFactory();
    final storage = FlutterSecureStorage();
    final analyticsService = AnalyticsService(
      analytics: analytics,
      crashlytics: crashlytics,
      performance: performance,
    );

    // Create service instances
    final firestoreUser = FirestoreUser(firestore: firestore, uid: uid);
    // Firestore credentials service
    final firestoreCredentials = FirestoreCredentials(
      firestoreUser: firestoreUser,
      cryptography: cryptography,
      itemFactory: itemFactory,
    );
    // Firestore homeworks service
    final firestoreHomeworks = FirestoreHomeworks(
      firestoreUser: firestoreUser,
      itemFactory: itemFactory,
    );
    // Firestore subjects service
    final firestoreSubjects = FirestoreSubjects(
      firestoreUser: firestoreUser,
      itemFactory: itemFactory,
    );

    final untisProvider = UntisProvider(
      range: range,
      analytics: analyticsService,
    );
    final homeworksProvider = HomeworksProvider(
      firestoreHomeworks: firestoreHomeworks,
      analyticsService: analyticsService,
    );
    final subjectProvider = SubjectProvider(
      firestoreSubjects: firestoreSubjects,
    );

    return MultiProvider(
      key: ValueKey(untisDemoMode),
      providers: [
        // Provides local and online credentials
        if (untisDemoMode) ...[
          ChangeNotifierProvider<CredentialProvider>(
            create: (_) => CredentialsDemoProvider(
              firestoreCredentials: firestoreCredentials,
            )..initialize(),
          ),

          ChangeNotifierProvider<UntisProvider>(
            create: (_) => UntisDemoProvider(range: range),
          ),
        ] else ...[
          ChangeNotifierProvider(
            create: (_) => CredentialProvider(
              firestoreCredentials: firestoreCredentials,
              itemFactory: itemFactory,
              storage: storage,
            )..initialize(),
            lazy: false,
          ),
          // Provides Untis session data based on credentials
          ChangeNotifierProxyProvider<CredentialProvider, UntisProvider>(
            create: (_) => untisProvider,
            update: (_, untisCredentialProvider, previous) =>
                (previous
                  ?..updateCredentials(untisCredentialProvider.session)) ??
                UntisProvider(range: range, analytics: analyticsService),
            lazy: false,
          ),
        ],
        // Provides homework data, updated when UntisProvider changes
        ChangeNotifierProvider<HomeworksProvider>(
          create: (_) => homeworksProvider,
          lazy: false,
        ),
        // Provides subject data, updated when UntisProvider changes
        ChangeNotifierProvider<SubjectProvider>(
          create: (_) => subjectProvider,
          lazy: false,
        ),
        ChangeNotifierProxyProvider3<
          UntisProvider,
          HomeworksProvider,
          SubjectProvider,
          SyncProvider
        >(
          create: (c) => SyncProvider(
            homeworksProvider: c.read(),
            untisProvider: c.read(),
            subjectProvider: c.read(),
            analyticsService: analyticsService,
          ),
          update: (
            _,
            untisProvider,
            homeworksProvider,
            subjectProvider,
            previous,
          ) => previous!..notifyListeners(),
        ),

        Provider<FirestoreUser>.value(value: firestoreUser),
        // Provides timetable data, updated when UntisProvider changes
        /*ChangeNotifierProvider(
          create: (_) => TimetableProvider(),
          lazy: false,
        ),*/
      ],
      // The child widget which now has access to all above providers
      child: child,
    );
  }
}
