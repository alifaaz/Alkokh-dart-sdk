class AlkokhMobileException implements Exception {
  AlkokhMobileException({
    required this.code,
    required this.message,
    this.statusCode,
    this.details,
  });

  final String code;
  final String message;
  final int? statusCode;
  final Object? details;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' HTTP $statusCode';
    return 'AlkokhMobileException$status: $code: $message';
  }
}

class AlkokhValidationException extends AlkokhMobileException {
  AlkokhValidationException(String message)
    : super(code: 'ValidationError', message: message);
}
