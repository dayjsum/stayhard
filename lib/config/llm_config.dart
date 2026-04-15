/// Compile-time wiring for optional LLM follow-ups.
///
/// ### Ollama (local, free runtime on your machine)
/// ```bash
/// flutter run ^
///   --dart-define=STAYHARD_LLM_BACKEND=ollama ^
///   --dart-define=STAYHARD_LLM_URL=http://10.0.2.2:11434 ^
///   --dart-define=STAYHARD_LLM_OLLAMA_MODEL=llama3.2
/// ```
/// - **Android emulator:** `10.0.2.2` reaches the host PC from the emulated device.
/// - **Android device:** use your PC LAN IP (e.g. `http://192.168.1.50:11434`) or `adb reverse`.
/// - **Windows desktop:** `http://127.0.0.1:11434`
///
/// If [backend] is empty or `auto`, port **11434** on [remoteUrl] is treated as Ollama.
///
/// ### Generic HTTP proxy (your API contract)
/// ```bash
/// flutter run --dart-define=STAYHARD_LLM_BACKEND=generic ^
///   --dart-define=STAYHARD_LLM_URL=https://api.example.com/v1/stayhard/line
/// ```
library;

abstract final class LlmConfig {
  /// `generic` = [RemoteLineGenerator] JSON contract.
  /// `ollama` = native `/api/generate`.
  /// `auto` = if [remoteUrl] port is 11434 use Ollama, else generic.
  static const String backend = String.fromEnvironment(
    'STAYHARD_LLM_BACKEND',
    defaultValue: 'auto',
  );

  static const String remoteUrl = String.fromEnvironment(
    'STAYHARD_LLM_URL',
    defaultValue: '',
  );

  /// Optional `Authorization: Bearer …` for **generic** backend only.
  static const String bearerToken = String.fromEnvironment(
    'STAYHARD_LLM_BEARER',
    defaultValue: '',
  );

  static const String ollamaModel = String.fromEnvironment(
    'STAYHARD_LLM_OLLAMA_MODEL',
    defaultValue: 'llama3.2',
  );

  /// Caps completion length (~tokens upper bound for many models).
  static const int ollamaNumPredict = int.fromEnvironment(
    'STAYHARD_LLM_OLLAMA_NUM_PREDICT',
    defaultValue: 120,
  );

  static const int timeoutSeconds = int.fromEnvironment(
    'STAYHARD_LLM_TIMEOUT_SEC',
    defaultValue: 30,
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

  static bool get useOllama {
    if (!isRemoteConfigured) return false;
    final b = backend.trim().toLowerCase();
    if (b == 'ollama') return true;
    if (b == 'generic') return false;
    // auto (default): Ollama’s default listen port
    final port = remoteUri?.port;
    return port == 11434;
  }

  static bool get useGenericHttp => isRemoteConfigured && !useOllama;
}
