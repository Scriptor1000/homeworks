import 'package:dart_untis_mobile/dart_untis_mobile.dart';

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

  Future<UntisSession> createUntisSession(UntisCredentials creds) {
    return UntisSession.init(
        creds.server, creds.school, creds.username, creds.password);
  }
}
