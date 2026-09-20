import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../provider/config_provider.dart';
import '../utilities/global_snackbar.dart';
import '../widgets/fab.dart';

typedef ConsentDialogResult = ({
  bool crashlyticsConsent,
  bool analyticsConsent,
  bool performanceConsent,
});

class ConsentDialogShell extends StatefulWidget {
  final Widget child;
  const ConsentDialogShell({super.key, required this.child});

  @override
  State<ConsentDialogShell> createState() => _ConsentDialogShellState();
}

class _ConsentDialogShellState extends State<ConsentDialogShell> {
  bool _dialogVisible = false;
  late ConfigProvider configProvider;

  @override
  void initState() {
    super.initState();
    configProvider = context.read<ConfigProvider>();
    configProvider.addListener(_updateFirebaseCollection);
  }

  @override
  Widget build(BuildContext context) {
    bool consentDialogShown = context.select(
      (ConfigProvider provider) => provider.consentDialogShown,
    );

    if (!consentDialogShown && !_dialogVisible) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => showConsentDialog(context),
      );
    }

    return widget.child;
  }

  Future<void> _updateFirebaseCollection() async {
    await FirebasePerformance.instance.setPerformanceCollectionEnabled(
      kReleaseMode && configProvider.performanceConsent,
    );
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(
      kReleaseMode && configProvider.analyticsConsent,
    );

    await FirebaseCrashlytics.instance.deleteUnsentReports();

    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      kReleaseMode && configProvider.crashlyticsConsent,
    );

    if (kReleaseMode && configProvider.crashlyticsConsent) {
      FlutterError.onError = (errorDetails) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    } else {
      FlutterError.onError = null;
      PlatformDispatcher.instance.onError = null;
    }
  }

  void showConsentDialog(BuildContext context) async {
    if (!context.mounted || _dialogVisible) return;
    setState(() {
      _dialogVisible = true;
    });
    ConfigProvider configProvider = context.read<ConfigProvider>();
    ConsentDialogResult? results = await showDialog<ConsentDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ConsentDialog(),
    );
    setState(() {
      _dialogVisible = false;
    });
    if (results == null) {
      showSnackBar(
        'Fehler: Die Auswahl konnte nicht registriert werden. Wiederhole... ',
      );
      showConsentDialog(currentContext ?? context);
      return;
    }
    configProvider.crashlyticsConsent = results.crashlyticsConsent;
    configProvider.analyticsConsent = results.analyticsConsent;
    configProvider.performanceConsent = results.performanceConsent;
    configProvider.consentDialogShown = true;
  }
}

class ConsentDialog extends StatefulWidget {
  const ConsentDialog({super.key});

  @override
  State<ConsentDialog> createState() => _ConsentDialogState();
}

class _ConsentDialogState extends State<ConsentDialog> {
  bool crashlyticsConsent = false;
  bool analyticsConsent = false;
  bool performanceConsent = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Zustimmung zur Datenerfassung'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Diese App wird als Teil einer Seminarfacharbeit entwickelt, für dessen Auswertung entsprechend unserer ',
                ),
                TextSpan(
                  text: 'Datenschutzerklärung',
                  style: const TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      final configProvider = context.read<ConfigProvider>();
                      final url = configProvider.privacyPolicyUrl;
                      launchUrl(Uri.parse(url));
                    },
                ),
                TextSpan(text: ' Daten gesammelt werden. '),
                TextSpan(
                  text:
                      'Wir schätzen Ihre Privatsphäre und möchten Ihre '
                      'Zustimmung einholen, bevor wir diese Daten erfassen. '
                      'Sie können ihre Zustimmung jederzeit in den Konto-Einstellungen der App ändern.'
                      'Mit der Zustimmung zur Datenerfassung helfen Sie uns, die App zu verbessern und wertvolle Einblicke zu gewinnen.'
                      'Mit Ihrer Zustimmung bestätigen sie außerdem, dass sie mindestens 16 Jahre alt sind und die Datenschutzerklärung zur Kenntnis genommen haben.',
                ),
              ],
            ),
          ),
          littleGap(),
          const Text(
            'Bitte wählen Sie aus, welche Daten Sie bereit sind zu teilen:',
          ),
          standardGap(),
          CheckboxListTile(
            title: const Text('Absturzberichte (Crashlytics)'),
            value: crashlyticsConsent,
            onChanged: (value) {
              setState(() {
                crashlyticsConsent = value ?? false;
              });
            },
          ),
          CheckboxListTile(
            title: const Text('Analyse (Analytics)'),
            value: analyticsConsent,
            onChanged: (value) {
              setState(() {
                analyticsConsent = value ?? false;
              });
            },
          ),
          CheckboxListTile(
            title: const Text('Leistungsüberwachung (Performance)'),
            value: performanceConsent,
            onChanged: (value) {
              setState(() {
                performanceConsent = value ?? false;
              });
            },
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop((
              crashlyticsConsent: crashlyticsConsent,
              analyticsConsent: analyticsConsent,
              performanceConsent: performanceConsent,
            ));
          },
          child: const Text('Auswahl akzeptieren'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop((
              crashlyticsConsent: true,
              analyticsConsent: true,
              performanceConsent: true,
            ));
          },
          child: const Text('Alle akzeptieren'),
        ),
      ],
    );
  }
}
