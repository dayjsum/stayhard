/// Your **hosted API** only — the app never runs an LLM; it POSTs a small JSON body.
///
/// ```bash
/// flutter run --dart-define=STAYHARD_LLM_URL=https://api.yourcompany.com/v1/stayhard/line ^
///   --dart-define=STAYHARD_LLM_BEARER=<user_session_jwt> ^
///   --dart-define=STAYHARD_LLM_TIMEOUT_SEC=20
/// ```
///
/// The server should: **lookup cache** by normalized user text (and context);
/// on miss call the LLM, **store** input+output; on hit return the stored line.
/// See `RemoteLineGenerator` for the `stayhard.line_request.v2` schema.
library;

abstract final class LlmConfig {
  static const String remoteUrl = String.fromEnvironment(
    'STAYHARD_LLM_URL',
    defaultValue: '',
  );

  /// Optional `Authorization: Bearer …` (short-lived user session from your auth).
  static const String bearerToken = String.fromEnvironment(
    'STAYHARD_LLM_BEARER',
    defaultValue: '',
  );

  static const int timeoutSeconds = int.fromEnvironment(
    'STAYHARD_LLM_TIMEOUT_SEC',
    defaultValue: 20,
  );

  static bool get isRemoteConfigured {
    final u = remoteUrl.trim();
    if (u.isEmpty) return false;
    final uri = Uri.tryParse(u);
    return uri != null && (uri.isScheme('https') || uri.isScheme('http'));
  }

  static Uri? get remoteUri {
    if (!isRemoteConfigured) return null;
    return Uri.parse(remoteUrl.trim());
  }
}
