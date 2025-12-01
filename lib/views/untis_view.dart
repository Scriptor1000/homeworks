import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../database/models/subject.dart';
import '../provider/credential_provider.dart';
import '../provider/subject_provider.dart';
import '../routes/typesafe_router.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Untis Verknüpfung')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const Divider(),
              const StatusCheck(),
              const Divider(),
              const FindTeacherTile(),
              const Divider(),
              Consumer(
                builder: (_, SubjectProvider provider, __) {
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
    );
  }
}

// Diese Klassen wurden aus setup.dart übernommen
class StatusCheck extends StatelessWidget {
  const StatusCheck({super.key});

  @override
  Widget build(BuildContext context) {
    final credentialProvider = context.watch<CredentialProvider>();
    final credentialsAvailable = credentialProvider.hasCredentials;
    final credentialsOnline = credentialProvider.credentialsOnlineStatus;

    return Column(
      children: [
        // TODO open edit
        credentialsAvailable
            ? const ListTile(
                leading: Icon(Icons.check_circle, color: Colors.green),
                title: Text('Mit deinem Untis Konto verknüpft.'),
                subtitle: Text(
                  'Deine Abgabezeiten orientieren sich an deinen Stundenplan.',
                ),
              )
            : ListTile(
                leading: const Icon(Icons.error, color: Colors.red),
                title: const Text('Nicht mit deinem Untis Konto verknüpft.'),
                subtitle: const Text('Klicke hier, um das zu ändern.'),
                onTap: () => const EnterCredentialsRoute().go(context),
              ),
        littleGap(),
        switch (credentialsOnline) {
          CredentailsOnlineStatus.loading => const ListTile(
            leading: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(),
            ),
            title: Text('Anmeldedaten online gespeichert'),
            subtitle: Text(
              'Es wird geprüft, ob deine Anmeldedaten online gespeichert sind.',
            ),
          ),
          CredentailsOnlineStatus.online =>
            credentialsAvailable
                ? const ListTile(
                    leading: Icon(Icons.check_circle, color: Colors.green),
                    title: Text('Anmeldedaten online gespeichert.'),
                    subtitle: Text(
                      'Deine Anmeldedaten sind online verschlüsselt gespeichert und auf allen Geräten verfügbar.',
                    ),
                  )
                : ListTile(
                    leading: const Icon(
                      Icons.check_circle,
                      color: Colors.yellow,
                    ),
                    title: const Text('Anmeldedaten online gespeichert.'),
                    subtitle: const Text(
                      'Deine Anmeldedaten sind online gespeichert, aber nicht auf diesem Gerät.',
                    ),
                    onTap: () => const DownloadCredentialsRoute().go(context),
                  ),
          CredentailsOnlineStatus.offline => ListTile(
            leading: const Icon(Icons.close, color: Colors.red),
            title: const Text('Anmeldedaten nicht online gespeichert.'),
            subtitle: Text(
              'Deine Anmeldedaten sind nicht online gespeichert.'
              "${credentialsAvailable ? "Klicke hier, um das zu ändern" : ""}",
            ),
            onTap: credentialsAvailable
                ? () => const UploadCredentialsRoute().go(context)
                : null,
          ),
          CredentailsOnlineStatus.error => const ListTile(
            leading: Icon(Icons.error, color: Colors.red),
            title: Text('Anmeldedaten online gespeichert.'),
            subtitle: Text(
              'Bei der Abfrage ist ein Fehler aufgetreten. Bitte überprüfe deine Internetverbindung.',
            ),
          ),
          CredentailsOnlineStatus.changed => const ListTile(
            leading: Icon(Icons.change_circle, color: Colors.yellow),
            title: Text('Andere Anmeldedaten online gespeichert.'),
            subtitle: Text(
              'Deine Anmeldedaten sind online gespeichert, stimmen aber nicht mit denen auf diesem Gerät überein.',
            ),
          ),
        },
      ],
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
       remainingSubjects = untisSubjects
           .where(
             (untisElement) =>
                 firestoreSubjects.indexWhere((e) => e.id == untisElement.id) !=
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
