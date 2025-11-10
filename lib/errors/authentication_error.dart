/// Exception thrown when a user is not authorized to perform an action.
/// Can be used to handle authentication or permission errors in the app.
class UnauthorizedException implements Exception {
  final String message;

  UnauthorizedException([this.message = 'Nicht autorisiert']);

  @override
  String toString() => 'UnauthorizedException: $message';
}
