import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import '../database/credentials.dart';
import '../database/homeworks.dart';
import '../database/models/factory.dart';
import '../database/subjects.dart';
import '../database/user.dart';
import '../provider/credential_provider.dart';
import '../provider/homeworks_provider.dart';
import '../provider/subject_provider.dart';
import '../provider/untis_provider.dart';
import '../utilities/analytics_service.dart';
import '../utilities/cryptography.dart';

/// A shell widget that makes the providers available to all routes.
class ProviderShell extends StatelessWidget {
  final Widget child;
  final String uid;

  const ProviderShell({
    super.key,
    required this.child,
    required this.uid,
  });

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    final analytics = FirebaseAnalytics.instance;
    // this could be a constant or config
    final range = const Duration(days: 30);

    // Cryptography utility for encrypting/decrypting credentials
    final cryptography = CredentialCryptography(uid: uid);
    // Factory to create data models
    final itemFactory = ItemFactory();
    final storage = FlutterSecureStorage();
    final analyticsService = AnalyticsService(analytics: analytics);

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

    return MultiProvider(
      providers: [
        // Provides local and online credentials
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
          create: (_) => UntisProvider(range: range),
          update: (_, untisCredentialProvider, previous) =>
              (previous?..updateCredentials(untisCredentialProvider.session)) ??
              UntisProvider(range: range),
          lazy: false,
        ),
        // Provides homework data, updated when UntisProvider changes
        ChangeNotifierProxyProvider<UntisProvider, HomeworksProvider>(
          create: (_) => HomeworksProvider(
            firestoreHomeworks: firestoreHomeworks,
            analyticsService: analyticsService,
          )..initialize(),
          update: (_, untisProvider, previous) =>
              (previous?..updateDueDates(untisProvider)) ??
              HomeworksProvider(
                firestoreHomeworks: firestoreHomeworks,
                analyticsService: analyticsService,
              ),
          lazy: false,
        ),
        // Provides subject data, updated when UntisProvider changes
        ChangeNotifierProxyProvider<UntisProvider, SubjectProvider>(
          create: (_) => SubjectProvider(
            firestoreSubjects: firestoreSubjects,
          )..initialize(),
          update: (_, untisAPIProvider, previous) =>
              (previous?..updateUntisSubjects(untisAPIProvider)) ??
              SubjectProvider(firestoreSubjects: firestoreSubjects),
          lazy: false,
        ),
      ],
      // The child widget which now has access to all above providers
      child: child,
    );
  }
}
