import 'package:dart_untis_mobile/dart_untis_mobile.dart';

import '../../utilities/enums.dart';
import 'credentials.dart';
import 'homework.dart';
import 'subject.dart';

/// A factory class to create domain objects from different sources.
///
/// This helps centralize object creation, especially when converting
/// from Firestore documents or JSON strings, and when creating Untis sessions.
class ItemFactory {
  /// Creates a [Homework] object from a Firestore document map.
  Homework homeworkFromDocument(Map<String, dynamic> data) {
    return Homework.fromDocument(data);
  }

  /// Creates a [Subject] object from a Firestore document map.
  Subject subjectFromDocument(Map<String, dynamic> data) {
    return Subject.fromDocument(data);
  }

  /// Parses a JSON string to create an [UntisCredentials] object.
  UntisCredentials untisCredentialsFromJSON(String jsonString) {
    return UntisCredentials.fromJsonString(jsonString);
  }
  /// Creates an [UntisSession] using the provided [UntisCredentials].
  ///
  /// This wraps the `UntisSession.init` method from the `dart_untis_mobile` package.
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
