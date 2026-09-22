import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../provider/config_provider.dart';

Widget buildPrivacyPolicyText(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  final configProvider = context.read<ConfigProvider>();

  return RichText(
    textAlign: TextAlign.center,
    text: TextSpan(
      style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
      children: [
        const TextSpan(
          text: 'Durch die Nutzung dieser App stimmen Sie unserer ',
        ),
        TextSpan(
          text: 'Datenschutzerklärung',
          style: TextStyle(
            color: colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              // Open the privacy policy URL in a web browser
              launchUrl(Uri.parse(configProvider.privacyPolicyUrl));
            },
        ),
        TextSpan(text: ' zu.'),
      ],
    ),
  );
}
