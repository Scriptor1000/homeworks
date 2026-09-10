import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../database/models/subject.dart';
import '../provider/credential_provider.dart';
import '../provider/subject_provider.dart';
import '../routes/typesafe_router.dart';
import '../utilities/common.dart';
import '../utilities/enums.dart';
import '../widgets/bottom_sheet_list.dart';
import '../widgets/fab.dart';
import '../widgets/select_teachers.dart';
import '../widgets/info_box.dart';

/// A view for managing the Untis integration.
/// It shows the current status of the Untis integration,
/// allows the user to log in to Untis or upload / download credentials.
/// It also provides an overview of the subjects from Untis and Firestore and
/// Options to import or delete these.
class UntisView extends StatefulWidget {
  const UntisView({super.key});

  @override
  State<UntisView> createState() => _UntisViewState();
}

class _UntisViewState extends State<UntisView> {
  List<Widget> subjectWidgets = [];

  @override
  Widget build(BuildContext context) {
    final CredentialProvider credentialProvider = context.watch();
    return Scaffold(
      appBar: AppBar(title: const Text('Untis Verknüpfung')),
      body: withConstrainedWidth(
        context,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const Divider(),
                const StatusCheck(),
                if (credentialProvider.sessionStatus ==
                    .sessionAccomplished) ...[
                  const Divider(),
                  const FindTeacherTile(),
                ],
                const Divider(),
                Consumer(
                  builder: (_, SubjectProvider provider, _) {
                    return SubjectOverview(
                      untisSubjects: provider.untisSubjects,
                      firestoreSubjects: provider.subjects,
                      subjectStatus: provider.untisSubjectStatus,
                    );
                  },
                ),
                const Divider(),
                // Hier könnten weitere Elemente hinzugefügt werden
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Diese Klassen wurden aus setup.dart übernommen
class StatusCheck extends StatelessWidget {
  const StatusCheck({super.key});

  @override
  Widget build(BuildContext context) {
    final credentialProvider = context.watch<CredentialProvider>();

    return Column(
      children: [
        buildLocalStatus(credentialProvider, context),
        littleGap(),
        buildOnlineStatus(credentialProvider, context),
      ],
    );
  }

  ListTile buildLocalStatus(
    CredentialProvider credentialProvider,
    BuildContext context,
  ) {
    final sessionStatus = credentialProvider.sessionStatus;
    final subtitle = switch (sessionStatus) {
      UntisSessionStatus.sessionAccomplished =>
        'Dein Stundenplan steht zur Verfügung, um dir unnötige Arbeit zu ersparen.',
      UntisSessionStatus.noCredentials => 'Klicke hier, um das zu ändern.',
      UntisSessionStatus.loading =>
        'Dein Stundenplan wird von Untis geladen...',
      UntisSessionStatus.invalidCredentials =>
        'Deine angegebenen Anmeldedaten scheinen ungültig zu sein.',
      UntisSessionStatus.error =>
        'Bei der Abfrage deines Stundenplans ist ein Fehler aufgetreten.',
    };
    final title = switch (sessionStatus) {
      UntisSessionStatus.sessionAccomplished =>
        'Mit deinem Untis Konto verbunden',
      UntisSessionStatus.noCredentials =>
        'Nicht mit deinem Untis Konto verbunden',
      UntisSessionStatus.loading => 'Verbindung wird hergestellt...',
      UntisSessionStatus.invalidCredentials =>
        'Fehler bei der Verknüpfung mit Untis',
      UntisSessionStatus.error => 'Fehler bei der Verknüpfung mit Untis',
    };
    final icon = switch (sessionStatus) {
      UntisSessionStatus.sessionAccomplished => const Icon(
        Icons.check_circle,
        color: Colors.green,
      ),
      UntisSessionStatus.loading => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(),
      ),
      _ => const Icon(Icons.error, color: Colors.red),
    };
    final onTap = sessionStatus != UntisSessionStatus.loading
        ? () => const EnterCredentialsRoute().go(context)
        : null;

    return ListTile(
      leading: icon,
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }

  ListTile buildOnlineStatus(
    CredentialProvider credentialProvider,
    BuildContext context,
  ) {
    final sessionStatus = credentialProvider.sessionStatus;
    final credentialsOnline = credentialProvider.credentialsOnlineStatus;

    final title = switch (credentialsOnline) {
      CredentialsOnlineStatus.online => 'Cloud Synchronisation aktiv',
      CredentialsOnlineStatus.offline => 'Cloud Synchronisation deaktiviert',
      CredentialsOnlineStatus.loading => 'Synchronisieren...',
      CredentialsOnlineStatus.error => 'Cloud Synchronisation fehlgeschlagen',
      CredentialsOnlineStatus.changed => 'Andere Anmeldedaten',
    };
    final subtitle = switch (credentialsOnline) {
      CredentialsOnlineStatus.online =>
        'Deine Anmeldedaten sind online verschlüsselt gespeichert und auf allen Geräten verfügbar.'
            '${credentialProvider.hasCredentials ? "" : " Tippe hier, um sie herunterzuladen."}',
      CredentialsOnlineStatus.offline =>
        'Deine Anmeldedaten sind nicht online gespeichert.'
            '${sessionStatus == UntisSessionStatus.sessionAccomplished ? "Klicke hier, um das zu ändern" : ""}',
      CredentialsOnlineStatus.loading =>
        'Es wird geprüft, ob deine Anmeldedaten online gespeichert sind.',
      CredentialsOnlineStatus.error =>
        'Bei der Abfrage ist ein Fehler aufgetreten. Bitte überprüfe deine Internetverbindung.',
      CredentialsOnlineStatus.changed =>
        'Es sind in der Cloud andere Anmeldedaten gespeichert als auf diesem Gerät. '
            'Tippe hier, um den Konflikt zu lösen.',
    };
    final icon = switch (credentialsOnline) {
      CredentialsOnlineStatus.online => const Icon(
        Icons.check_circle,
        color: Colors.green,
      ),
      CredentialsOnlineStatus.loading => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(),
      ),
      CredentialsOnlineStatus.changed => const Icon(
        Icons.change_circle,
        color: Colors.yellow,
      ),
      _ => const Icon(Icons.close, color: Colors.red),
    };
    final onTap = switch (credentialsOnline) {
      CredentialsOnlineStatus.online =>
        credentialProvider.hasCredentials
            ? () => const UploadCredentialsRoute().go(context)
            : () => const DownloadCredentialsRoute().go(context),
      CredentialsOnlineStatus.offline =>
        sessionStatus == UntisSessionStatus.sessionAccomplished
            ? () => const UploadCredentialsRoute().go(context)
            : null,
      CredentialsOnlineStatus.changed => () => showChangeDialog(
        credentialProvider.sessionStatus ==
            UntisSessionStatus.sessionAccomplished,
        context,
      ),
      _ => null,
    };

    return ListTile(
      leading: icon,
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }

  Future<void> showChangeDialog(
    bool localeCredentialsFunctional,
    BuildContext context,
  ) async {
    final colorScheme = Theme.of(context).colorScheme;
    final preferredStyle = ButtonStyle(
      backgroundColor: WidgetStatePropertyAll(colorScheme.primaryContainer),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.bold),
      ),
    );
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Anmeldedaten aktualisieren'),
          scrollable: true,
          content: InfoBox(
            paragraphs: [
              if (localeCredentialsFunctional)
                'Es sind bereits funktionierende Anmeldedaten auf diesem Gerät gespeichert.\n'
                    'Du solltest diese in die Cloud hochladen.'
              else
                'Es gibt keine funktionierenden Anmeldedaten auf diesem Gerät.\n'
                    'Du solltest die online gespeicherten Anmeldedaten herunterladen.',
            ],
            title: 'Hinweis',
          ),
          actions: [
            TextButton(
              onPressed: () {
                context.pop();
                const UploadCredentialsRoute().go(context);
              },
              style: localeCredentialsFunctional ? preferredStyle : null,
              child: const Text('Lokale Anmeldedaten hochladen'),
            ),
            TextButton(
              onPressed: () {
                context.pop();
                const DownloadCredentialsRoute().go(context);
              },
              style: !localeCredentialsFunctional ? preferredStyle : null,
              child: const Text('Online Anmeldedaten laden'),
            ),
          ],
        );
      },
    );
  }
}

class SubjectOverview extends StatelessWidget {
  SubjectOverview({
    super.key,
    required this.untisSubjects,
    required this.firestoreSubjects,
    required this.subjectStatus,
  }) : unitsButNotInFirestore = untisSubjects
           .where(
             (untisElement) =>
                 firestoreSubjects.indexWhere((e) => e.id == untisElement.id) ==
                 -1,
           )
           .toList(),
       firestoreButNotInUntis = firestoreSubjects
           .where(
             (firestoreElement) =>
                 untisSubjects.indexWhere((e) => e.id == firestoreElement.id) ==
                 -1,
           )
           .toList(),
       remainingSubjects = firestoreSubjects
           .where(
             (firestoreElement) =>
                 untisSubjects.indexWhere((e) => e.id == firestoreElement.id) !=
                 -1,
           )
           .toList();

  final List<Subject> untisSubjects;
  final List<Subject> firestoreSubjects;
  final UntisSubjectStatus subjectStatus;

  final List<Subject> unitsButNotInFirestore;
  final List<Subject> firestoreButNotInUntis;
  final List<Subject> remainingSubjects;

  @override
  Widget build(BuildContext context) {
    return switch (subjectStatus) {
      UntisSubjectStatus.untisUnavailable =>
        firestoreSubjects.isEmpty
            ? const ListTile(title: Text('Keine Fächer vorhanden'))
            : Column(
                children: [
                  const InfoBox(
                    paragraphs: [
                      'Deine Fächer konnten nicht aktualisiert werden, da du nicht mit einem Untis-Konto verknüpft bist.',
                    ],
                    title: 'Information',
                    icon: Icons.warning_amber_rounded,
                    accentColor: Colors.amber,
                  ),
                  littleGap(),
                  ListTile(
                    title: Text(
                      '${firestoreSubjects.length} importierte Fächer',
                    ),
                    onTap: () => showBottomSheet(
                      context,
                      SubjectListType.inFirestoreUntisNotAvailable,
                    ),
                  ),
                ],
              ),
      UntisSubjectStatus.loading => const ListTile(
        title: Text('Fächer werden geladen...'),
        leading: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(),
        ),
      ),
      UntisSubjectStatus.error => const ListTile(
        title: Text('Fehler beim Laden der Fächer'),
        leading: Icon(Icons.error, color: Colors.red),
      ),
      UntisSubjectStatus.loaded => Column(
        children: [
          if (unitsButNotInFirestore.isNotEmpty)
            ListTile(
              title: Text(
                '${unitsButNotInFirestore.length} neue Fächer in Untis gefunden',
              ),
              onTap: () => showBottomSheet(
                context,
                SubjectListType.inUnitsButNotInFirestore,
              ),
              leading: const FaIcon(FontAwesomeIcons.folderPlus),
            ),
          if (firestoreButNotInUntis.isNotEmpty)
            ListTile(
              title: Text(
                '${firestoreButNotInUntis.length} Fächer, die nicht mehr in Untis sind',
              ),
              onTap: () => showBottomSheet(
                context,
                SubjectListType.inFirestoreButNotInUntis,
              ),
              leading: const FaIcon(FontAwesomeIcons.folderMinus),
            ),
          if (remainingSubjects.isNotEmpty)
            ListTile(
              title: Text('${remainingSubjects.length} Importierte Fächer'),
              onTap: () => showBottomSheet(context, SubjectListType.inBoth),
              leading: const Icon(Icons.check),
            ),
        ],
      ),
    };
  }

  void showBottomSheet(
    BuildContext context,
    SubjectListType subjectListType, {
    List<Subject>? subjects,
  }) {
    subjects ??= switch (subjectListType) {
      SubjectListType.inUnitsButNotInFirestore => unitsButNotInFirestore,
      SubjectListType.inFirestoreButNotInUntis => firestoreButNotInUntis,
      SubjectListType.inBoth => remainingSubjects,
      SubjectListType.inFirestoreUntisNotAvailable => firestoreSubjects,
    };

    String title = switch (subjectListType) {
      SubjectListType.inUnitsButNotInFirestore =>
        'neue Fächer in Untis gefunden',
      SubjectListType.inFirestoreButNotInUntis =>
        'Fächer, die nicht mehr in Untis sind',
      SubjectListType.inBoth => 'Importierte Fächer',
      SubjectListType.inFirestoreUntisNotAvailable => 'Importierte Fächer',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).canvasColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.6,
          child: SubjectBottomSheetContent(
            title: title,
            initialSubjects: subjects!,
            subjectListType: subjectListType,
          ),
        );
      },
    );
  }
}
