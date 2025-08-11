class UnauthorizedException implements Exception {
  final String message;

  UnauthorizedException([this.message = 'Nicht autorisiert']);

  @override
  String toString() => 'UnauthorizedException: $message';
}
