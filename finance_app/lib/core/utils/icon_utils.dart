import 'package:flutter/material.dart' show IconData;

/// Returns [IconData] for the given Material icon [codePoint].
///
/// Category icons are stored in Firestore as integer codePoints (runtime
/// values). This helper centralises the [IconData] construction so the
/// lint suppression appears in exactly one place rather than in every widget.
IconData materialIconData(int codePoint) {
  // ignore: non_const_argument_for_const_parameter
  return IconData(codePoint, fontFamily: 'MaterialIcons');
}
