import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Friendly error the UI can show directly (e.g. 'Not enough coins').
class BackendException implements Exception {
  final String message;
  BackendException(this.message);
  @override
  String toString() => message;
}

/// Thin wrapper around the Cloud Functions in /functions.
/// The app never sees the Gemini key and never writes coins: it only calls these.
class BackendService {
  BackendService._();
  static final BackendService instance = BackendService._();

  /// Call once in main() right after Firebase.initializeApp(), only while testing with emulators.
  static void useEmulator({String host = '127.0.0.1', int port = 5001}) {
    FirebaseFunctions.instanceFor(region: 'us-central1').useFunctionsEmulator(host, port);
  }

  final _fn = FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<Map<String, dynamic>> _call(String name, [Map<String, dynamic>? data]) async {
    try {
      final res = await _fn
          .httpsCallable(name, options: HttpsCallableOptions(timeout: const Duration(seconds: 300)))
          .call(data ?? {});
      return Map<String, dynamic>.from(res.data as Map);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Function $name failed: ${e.code} ${e.message}');
      throw BackendException(e.message ?? 'Something went wrong. Please try again.');
    }
  }

  // ---- user + wallet (call right after Google sign-in) ----
  Future<void> initUser() => _call('initUser');

  // ---- Task Shredder (creator) ----
  /// Brief in, priced draft tasks out. Pass [projectId] to regenerate an existing draft.
  Future<Map<String, dynamic>> shredProject({required String title, required String brief, String? projectId}) =>
      _call('shredProject', {'title': title, 'brief': brief, if (projectId != null) 'projectId': projectId});

  /// Coins are never sent. Changing title/description/context re-prices the task on the server.
  Future<Map<String, dynamic>> updateTask(String taskId, Map<String, dynamic> fields) =>
      _call('updateTask', {'taskId': taskId, 'fields': fields});

  Future<Map<String, dynamic>> deleteTask(String taskId) => _call('deleteTask', {'taskId': taskId});

  /// Balance check + escrow hold. Throws BackendException('Not enough coins') when short.
  Future<Map<String, dynamic>> publishProject(String projectId) => _call('publishProject', {'projectId': projectId});

  // ---- contributor ----
  /// Returns {claimId, deadlineMs}. Throws BackendException with a friendly reason (quest gate, level gate, sprint over...).
  Future<Map<String, dynamic>> claimTask(String taskId) => _call('claimTask', {'taskId': taskId});

  // ---- micro-squads (2 to 3 people share one claim and split the reward) ----
  Future<Map<String, dynamic>> createSquad(String taskId) => _call('createSquad', {'taskId': taskId});
  Future<Map<String, dynamic>> joinSquad(String claimId) => _call('joinSquad', {'claimId': claimId});

  // ---- Proving Grounds ----
  /// Returns the open quest or makes a new one: {id, skill, prompt, reward, difficulty}. difficulty: easy | medium | hard.
  Future<Map<String, dynamic>> getQuest({String? skill, String? difficulty}) =>
      _call('getQuest', {if (skill != null) 'skill': skill, if (difficulty != null) 'difficulty': difficulty});
  /// Returns {passed, score, feedback, reward}.
  Future<Map<String, dynamic>> submitQuest(String questId, String answer) =>
      _call('submitQuest', {'questId': questId, 'answer': answer});

  // ---- public skill tree ----
  /// Returns {slug, payload}. Share the link as https://<your-host>/p/<slug>.
  Future<Map<String, dynamic>> publishPortfolio() => _call('publishPortfolio');
  Future<bool> verifyPortfolio(String slug) async => (await _call('verifyPortfolio', {'slug': slug}))['valid'] == true;

  /// Emulator only: runs the hourly surge + sprint-expiry job right now (for demos).
  Future<Map<String, dynamic>> debugSweep() => _call('debugSweep');

  /// Returns {ok:false, message} when a rule check fails (show message), else {ok:true, submissionId}.
  Future<Map<String, dynamic>> submitWork(String claimId, String text) =>
      _call('submitWork', {'claimId': claimId, 'text': text});

  // ---- owner review ----
  Future<Map<String, dynamic>> decide(String submissionId, String decision,
          {String note = '', int? finalScore, List<Map<String, dynamic>>? criterionOverrides}) =>
      _call('decideSubmission', {
        'submissionId': submissionId,
        'decision': decision, // accepted | changes_requested | rejected
        'ownerNote': note,
        if (finalScore != null) 'finalScore': finalScore,
        if (criterionOverrides != null) 'criterionOverrides': criterionOverrides,
      });

  Future<Map<String, dynamic>> pickWinner(String submissionId) => _call('pickWinner', {'submissionId': submissionId});
  /// Undo a spam discard (refunds the penalty).
  Future<Map<String, dynamic>> restoreSubmission(String submissionId) => _call('restoreSubmission', {'submissionId': submissionId});
  Future<Map<String, dynamic>> rerunReview(String submissionId) => _call('rerunReview', {'submissionId': submissionId});
  Future<Map<String, dynamic>> closeTask(String taskId) => _call('closeTask', {'taskId': taskId});
  Future<Map<String, dynamic>> closeProject(String projectId) => _call('closeProject', {'projectId': projectId});
}
