import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/ai_assistant_service.dart';
import '../domain/chat_message_model.dart';

// ── Service provider ───────────────────────────────────────────────────────────

final aiAssistantServiceProvider = Provider<AiAssistantService>((ref) {
  return AiAssistantService(FirebaseFirestore.instance);
});

// ── Chat history ───────────────────────────────────────────────────────────────

/// Loads the user's last 50 chat messages from Firestore on mount.
/// The screen manages the live in-memory list itself after initial load.
final chatHistoryProvider =
    FutureProvider.autoDispose<List<ChatMessageModel>>((ref) async {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) return [];
  return ref.read(aiAssistantServiceProvider).getChatHistory(user.uid);
});
