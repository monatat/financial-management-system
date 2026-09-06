import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/export_service.dart';

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(FirebaseFirestore.instance);
});
