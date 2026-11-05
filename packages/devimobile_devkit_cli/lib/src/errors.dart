/// A problem with the environment or configuration that stops a command.
///
/// The CLI prints [message] and exits with code 2.
final class DevkitException implements Exception {
  const DevkitException(this.message);

  final String message;

  @override
  String toString() => message;
}
