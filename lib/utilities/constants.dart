/// Class wich static values for border radii used in the app.
/// These values are used to ensure a consistent design across the application.
class BorderRadiusConstants {
  static const double subjects = 20;
  static const double homeworks = 20;
  static const double textFields = 15;
  static const double infoBox = 20;
  static const double listTiles = 20;
}

/// Class wich static values for horizontal padding used in the app.
/// These values are used to ensure a consistent design across the application.
class HorizontalPaddingConstants {
  // TODO
}

/// List of prefixes for exam Homeworks.
/// These prefixes are used to identify exams in [FirestoreProvider.fastCreateHomework].
const List<String> examPrefixes = ['LK ', 'LK: ', 'Test ', 'Test: '];
