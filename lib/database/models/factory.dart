import 'package:dart_untis_mobile/dart_untis_mobile.dart';

import '../../utilities/enums.dart';
import 'credentials.dart';
import 'homework.dart';
import 'subject.dart';

class ItemFactory {
  Homework homeworkFromDocument(Map<String, dynamic> data) {
    return Homework.fromDocument(data);
  }

  Subject subjectFromDocument(Map<String, dynamic> data) {
    return Subject.fromDocument(data);
  }

  UntisCredentials untisCredentialsFromJSON(String jsonString) {
    return UntisCredentials.fromJsonString(jsonString);
  }

  Future<SessionResult> createUntisSession(UntisCredentials creds) async {
    try {
      final session = await UntisSession.init(
        creds.server,
        creds.school,
        creds.username,
        creds.password,
      );
      return SessionResult(session, UntisSessionStatus.sessionAccomplished);
    } catch (e) {
      if (e.toString().toLowerCase().contains('authentication failed')) {
        // This specific hashCode corresponds to an invalid credentials error.
        // It is not ideal to rely on hashCodes for error handling, but the underlying
        // library does not provide specific exception types.
        return SessionResult(null, UntisSessionStatus.invalidCredentials);
      } else {
        return SessionResult(null, UntisSessionStatus.error);
      }
    }
  }
}

class SessionResult {
  const SessionResult(this.session, this.status);
  final UntisSession? session;
  final UntisSessionStatus status;
}
