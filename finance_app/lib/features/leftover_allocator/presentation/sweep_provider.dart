import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/sweep_service.dart';

// ── Service provider ───────────────────────────────────────────────────────────

final sweepServiceProvider = Provider<SweepService>((ref) {
  return SweepService(FirebaseFirestore.instance);
});
