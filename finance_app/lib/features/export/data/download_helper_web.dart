// Web-specific file — only compiled when dart.library.html is available.
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

/// Triggers a browser file download with [bytes] as the content.
///
/// IMPORTANT: [bytes] must be converted to [Uint8List] before passing to
/// [html.Blob]. Passing a plain Dart [List<int>] causes JavaScript's Blob
/// constructor to call `.toString()` on the list, producing a string of
/// comma-separated decimal numbers (e.g. "239,187,191,70,105,...") instead of
/// treating the data as binary — which is the CSV corruption bug.
Future<void> downloadBytes(
  String filename,
  List<int> bytes,
  String mimeType,
) async {
  // Convert to Uint8List so the JS runtime sees a Uint8Array (binary data),
  // not a plain array whose toString() gives "239,187,191,...".
  final uint8Data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

  final blob = html.Blob([uint8Data], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
