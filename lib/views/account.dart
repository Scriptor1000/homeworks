import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../provider/config_provider.dart';
import '../utilities/common.dart';
import '../widgets/fab.dart';
import '../widgets/user_container.dart';

/// A widget for displaying the account actions and information.
/// Later this can be extended with settings and other options which doesn't have to do with the account management.
class AccountView extends StatelessWidget {
  const AccountView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Konto')),
      body: withConstrainedWidth(
        context,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              children: [
                UserContainer(),
                littleGap(),
                _buildOpenSourceLicensesButton(context),
                littleGap(),
                _buildConsentDialogButton(context),
                littleGap(),
                _buildLinkToPrivacyPolicy(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOpenSourceLicensesButton(BuildContext context) {
    return ListTile(
      onTap: () {
        showLicensePage(context: context, applicationName: 'Homeworks');
      },
      title: Text('Open Source Lizenzen'),
      leading: FaIcon(FontAwesomeIcons.copyright),
    );
  }

  Widget _buildConsentDialogButton(BuildContext context) {
    return ListTile(
      onTap: () {
        context.read<ConfigProvider>().consentDialogShown = false;
      },
      title: Text('Zustimmungseinstellungen'),
      leading: Icon(Icons.privacy_tip_outlined),
    );
  }

  Widget _buildLinkToPrivacyPolicy(BuildContext context) {
    return ListTile(
      onTap: () {
        final configProvider = context.read<ConfigProvider>();
        final url = configProvider.privacyPolicyUrl;
        launchUrl(Uri.parse(url));
      },
      title: Text('Datenschutzerklärung'),
      leading: Icon(Icons.link),
    );
  }
}
