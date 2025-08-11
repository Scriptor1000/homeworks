import 'dart:async';

import 'package:flutter/material.dart';

import '../utilities/global_snackbar.dart';
import 'fab.dart';

class DeepNextLessonSearchSnackbar {
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _controller;
// TODO to Dialog?
// FIXME creates many errors (like when activated twice)
  static void show(Stream<DateTime> stream, Completer<void> aborter) async {
    // _controller?.close();
    _controller = await showComplexSnackBar(
      SnackBar(
        content: StreamBuilder<DateTime>(
          stream: Stream.empty(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final checkStart = snapshot.data!;
              final checkEnd = checkStart.add(const Duration(days: 7));
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  standardGap(),
                  Text(
                    'Suche vom ${checkStart.day}.${checkStart.month}.${checkStart.year}'
                    ' bis zum ${checkEnd.day}.${checkEnd.month}.${checkEnd.year}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              );
            } else if (snapshot.hasError) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  standardGap(),
                  Text('Fehler: ${snapshot.error}'),
                ],
              );
            } else {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  standardGap(),
                  const Text('Initialisiere Suche...'),
                ],
              );
            }
          },
        ),
        duration: const Duration(days: 365), // Long duration to keep it open
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Abbrechen',
          onPressed: () {
            _controller?.close();
          },
        ),
      ),
    );
    _controller?.closed.then((reason) {
      if (!aborter.isCompleted) {
        aborter.complete();
      }
    });
    aborter.future.then((_) {
      if (_controller != null) {
        _controller!.close();
      }
    });
  }

  static void close() {
    _controller?.close();
    _controller = null;
  }
}
