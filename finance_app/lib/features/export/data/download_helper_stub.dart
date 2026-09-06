/// Non-web stub — download is not supported on mobile/desktop.
/// The ExportScreen shows a message redirecting users to the web version.
Future<void> downloadBytes(
  String filename,
  List<int> bytes,
  String mimeType,
) async {
  // No-op on non-web platforms.
}
