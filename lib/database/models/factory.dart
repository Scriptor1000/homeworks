import 'package:dart_untis_mobile/dart_untis_mobile.dart';

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
  Future<UntisSession> createUntisSession(UntisCredentials creds) {
    return UntisSession.init(
        creds.server, creds.school, creds.username, creds.password);
  }
}
