import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'database/allowed_emails.dart';
import 'firebase_options.dart';
import 'provider/authentication_provider.dart';
import 'routes/typesafe_router.dart';
import 'utilities/constants.dart';
import 'utilities/global_snackbar.dart';

const sentryReleaseName = String.fromEnvironment('SENTRY_RELEASE');

void main() async {
  /// The following line enables that the URL shows the last route on the stack,
  /// even if it was pushed. Standard behavior is that the URL only shows routes you [go] to.
  /// GoRouter.optionURLReflectsImperativeAPIs = true;

  WidgetsBinding widgetsBinding =
      SentryWidgetsFlutterBinding.ensureInitialized();

  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  usePathUrlStrategy();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(kReleaseMode);

  FlutterNativeSplash.remove();
  if (kReleaseMode) {
    await SentryFlutter.init((options) {
      options.dsn =
          'https://2937d7b0e20d869f78933ba866a6c078@o4510119803092992.ingest.de.sentry.io/4510119812661328';
      options.enableAutoSessionTracking = true;

      if (sentryReleaseName.isNotEmpty) {
        options.release = sentryReleaseName;
        options.environment = sentryReleaseName.split('@').first == 'main'
            ? 'production'
            : 'staging';
      }
    }, appRunner: () => runApp(SentryWidget(child: const MainApp())));
  } else {
    runApp(const MainApp());
  }
}

/// Root widget of the application.
/// Sets up theming, localization, routing, and authentication provider wrapper.
class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    // DynamicColorBuilder automatically adapts the app colors to system theme
    // (Android 12+), falling back to a seeded color scheme otherwise.
    return DynamicColorBuilder(builder: (light, dark) {
      light ??= ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      );
      dark ??= ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      );

      // Wrap the MaterialApp in the authentication provider shell
      // so the whole widget tree has access to AuthenticationProvider.
      return authenticationProviderShell(
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: scaffoldMessengerKey, // Snackbar manager
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: _buildTheme(light, Brightness.light),
          darkTheme: _buildTheme(dark, Brightness.dark),
          themeMode: ThemeMode.system, // Use system light/dark preference
          routerConfig: appRouter, // Main router
          supportedLocales: const [
            Locale('de', 'DE'),
            Locale('en', 'US'),
          ],
          locale: const Locale('de', 'DE'),
        ),
      );
    });
  }

  /// Builds and returns a customized theme for a given ColorScheme and brightness.
  /// Standardizes look of text fields, tiles, borders, etc.
  ThemeData _buildTheme(ColorScheme colorScheme, Brightness brightness) {
    var standardInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(BorderRadiusConstants.textFields),
      borderSide: const BorderSide(color: Colors.grey),
    );

    return ThemeData(
      colorScheme: colorScheme,
      brightness: brightness,
      useMaterial3: true, // Use Material 3 design
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BorderRadiusConstants.listTiles),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
          border: standardInputBorder,
          enabledBorder: standardInputBorder,
          focusedBorder: OutlineInputBorder(
            borderRadius: standardInputBorder.borderRadius,
            borderSide: BorderSide(
              color: colorScheme.primary,
              width: 2,
            ),
          ),
          disabledBorder: standardInputBorder),
    );
  }
}

///
/// Provides the AuthenticationProvider to the widget tree.
/// Initializes FirebaseAuth, GoogleSignIn, and allowed email list,
/// then exposes them via ChangeNotifierProvider.
///
/// This ensures authentication state and logic is available everywhere.
///
Widget authenticationProviderShell({required Widget child}) {
  final firebaseAuth = FirebaseAuth.instance;  // Get the shared Firebase Authentication instance
  final googleSignIn = GoogleSignIn.instance;  // Get the shared Google Sign-In service

  // Create helper to check Firestore for allowed email accounts
  final allowedEmails =
      FirestoreAllowedEmails(firestore: FirebaseFirestore.instance);

  // Provide AuthenticationProvider to descendant widgets
  // and run initialize() right away (.. syntax = cascade)
  return ChangeNotifierProvider<AuthenticationProvider>(
    create: (BuildContext context) => AuthenticationProvider(
      firebaseAuth: firebaseAuth,
      googleSignIn: googleSignIn,
      allowedEmails: allowedEmails,
    )..initialize(),
    child: child, // The widget subtree that needs auth context
  );
}
