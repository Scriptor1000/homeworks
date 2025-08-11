import 'package:flutter/material.dart';

/// Global key for the ScaffoldMessenger to show SnackBars across the app,
/// even in async operations wihtout a context.
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

// TODO: general better error handling (global)
/// Shows a SnackBar with the given [message].
void showSnackBar(String message) {
  Future.delayed(Duration.zero, () {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  });
}

Future<ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?>
    showComplexSnackBar(SnackBar snackBar) {
  return Future.delayed(Duration.zero,
      () => scaffoldMessengerKey.currentState?.showSnackBar(snackBar));
}
