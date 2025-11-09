import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

void main() async {
  // The following line enables that the URL shows the last route on the stack,
  // even if it was pushed. Stanard behavior is that the URL only shows routes you [go] to.
  // GoRouter.optionURLReflectsImperativeAPIs = true;

  SentryWidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(kReleaseMode);

  if (kDebugMode) {
    runApp(const MainApp());
  } else {
    await SentryFlutter.init(
      (options) {
        options.dsn =
            'https://2937d7b0e20d869f78933ba866a6c078@o4510119803092992.ingest.de.sentry.io/4510119812661328';
        options.environment = kDebugMode ? 'development' : 'production';
        options.tracesSampleRate = 0.0; // Performance-Tracking aus
        options.enableAutoSessionTracking = true;
        options.attachStacktrace = true;
        options.replay.onErrorSampleRate = 0.2;
      },
      appRunner: () => runApp(SentryWidget(child: const MainApp())),
    );
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(builder: (light, dark) {
      light ??= ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      );
      dark ??= ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      );

      return authenticationProviderShell(
        child: MaterialApp.router(
          scaffoldMessengerKey: scaffoldMessengerKey,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: _buildTheme(light, Brightness.light),
          darkTheme: _buildTheme(dark, Brightness.dark),
          themeMode: ThemeMode.system,
          routerConfig: appRouter,
          supportedLocales: const [
            Locale('de', 'DE'),
            Locale('en', 'US'),
          ],
          locale: const Locale('de', 'DE'),
        ),
      );
    });
  }

  ThemeData _buildTheme(ColorScheme colorScheme, Brightness brightness) {
    var standardInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(BorderRadiusConstants.textFields),
      borderSide: const BorderSide(color: Colors.grey),
    );
    return ThemeData(
      colorScheme: colorScheme,
      brightness: brightness,
      useMaterial3: true,
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

Widget authenticationProviderShell({required Widget child}) {
  final firebaseAuth = FirebaseAuth.instance;
  final googleSignIn = GoogleSignIn.instance;
  final allowedEmails =
      FirestoreAllowedEmails(firestore: FirebaseFirestore.instance);

  return ChangeNotifierProvider<AuthenticationProvider>(
    create: (BuildContext context) => AuthenticationProvider(
        firebaseAuth: firebaseAuth,
        googleSignIn: googleSignIn,
        allowedEmails: allowedEmails)
      ..initialize(),
    child: child,
  );
}
