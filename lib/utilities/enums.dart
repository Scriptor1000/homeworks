/// The status of the credentials online check.
enum CredentailsOnlineStatus {
  /// The credentials are online and match the local credentials.
  online,

  /// The online status is currently being checked.
  loading,

  /// The credentials are not storred online.
  offline,

  /// The credentials are online but do not match the local credentials.
  changed,

  /// An error occurred while checking the online status.
  error,
}

enum UntisSessionStatus {
  noCredentials,
  loading,
  sessionAccomplished,
  invalidCredentials,
  error,
}

/// The status of the subjects wich are loaded from Untis.
enum UntisSubjectStatus {
  /// There are no Untis credentials wich could be used to get Subjects from Untis.
  untisUnavailable,

  /// The subjects are currently being fetched from Untis.
  loading,

  /// The subjects from Untis are loaded and available.
  loaded,

  /// An error occurred while loading Untis subjects.
  error,
}

/// The status of the subjects loaded from Firestore.
enum FirestoreSubjectStatus {
  /// Firestore is not available or the user is not logged in.
  firestoreUnavailable,

  /// The subjects are currently being fetched from Firestore.
  loading,

  /// The subjects from Firestore are loaded and available.
  loaded,

  /// An error occurred while loading subjects from Firestore.
  error,
}

/// The types a list of subjects can have when comparing Untis and Firestore subjects.
enum SubjectListType {
  /// Subjects that are in the timetable from Untis but not stored in Firestore.
  inUnitsButNotInFirestore,

  /// Subjects that are stored in Firestore but no longer part of the Untis timetable.
  inFirestoreButNotInUntis,

  /// Subjects that are in both in the timtable and in Firestore.
  inBoth,

  /// Subjects that are stored in Firestore but cannot be compared to Untis subjects,
  /// because Untis subjects are not available (because there are no Credentials).
  inFirestoreUntisNotAvailable,
}

enum GoogleSignInState {
  supported,
  notSupported,
  needWebButton,
  error,
  loading,
}
