import 'package:flutter/material.dart';

import '../widgets/user_container.dart';

/// A widget for displaying the account actions and information.
/// Later this can be extended with settings and other options which doesn't have to do with the account management.
class AccountView extends StatelessWidget {
  const AccountView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Konto')),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              UserContainer(),
              // Hier kann später weiterer Inhalt für die Account-Seite eingefügt werden
              TextButton(
                onPressed: () {
                  // Show a dialog to confirm the crash test
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Test Crash'),
                        content: const Text(
                          'Möchten Sie die App wirklich zum Absturz bringen?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop(); // Close the dialog
                            },
                            child: const Text('Abbrechen'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              throw Exception('Test Crash ausgelöst');
                            },
                            child: const Text('Ja, Crash auslösen'),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: Text('Test Crash'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
