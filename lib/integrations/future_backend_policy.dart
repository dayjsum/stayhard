/// Planned **server-side** behavior for accounts, bans, and LLM/SMS abuse prevention.
///
/// Client calls **only your HTTPS API** (`llm_config.dart` + `RemoteLineGenerator`).
/// Cache + LLM live on the server; the app never runs a model.
///
/// The Flutter app must **not** be the source of truth for bans or rate limits: anyone
/// can modify the client, clear storage, or script HTTP. All enforcement belongs in
/// your API + database + edge (API gateway / WAF).
library;

// -----------------------------------------------------------------------------
// Email ban after failing “Stay Hard”
// -----------------------------------------------------------------------------
//
// 1. **Define “failure” in code you control** (e.g. N missed commitments in a row,
//    or explicit “I quit” — not a single missed notification).
// 2. On failure: set `account_status = banned` (or `ineligible_until`) in the DB,
//    revoke **refresh tokens**, and optionally add **email hash** to a blocklist so
//    the same address cannot re-enroll without ops review.
// 3. **New start = new verified email** — enforce uniqueness + verification on signup;
//    reject signups whose normalized email hash matches `banned_email_hashes`.
// 4. **Privacy / compliance**: document retention, deletion requests, and whether
//    you keep a hash-only blocklist vs raw email (hash + salt is typical).
//
// The app can *display* “account locked” after the API returns 403 — it cannot
// *prove* a ban by itself.

// -----------------------------------------------------------------------------
// Anti-spam / anti–token-burn (LLM, Twilio, or any metered API)
// -----------------------------------------------------------------------------
//
// Apply **before** calling the model or sending SMS:
//
// - **AuthN**: reject anonymous or invalid JWT; short-lived access tokens.
// - **Rate limits** (sliding window): per `user_id`, per `ip`, and optionally per
//   `device_installation_id` (opaque ID issued at signup, not hardware ID if policy
//   forbids). Return **429** + `Retry-After` when exceeded.
// - **Payload caps**: max body length, max messages per session, reject empty /
//   repeated / ultra-high-frequency payloads (hash last message to dedupe bursts).
// - **Idempotency-Key** on POSTs so retries do not double-charge tokens.
// - **Budgets**: hard daily token (or cost) ceiling per user/plan; optional queue for
//   overflow instead of synchronous LLM.
// - **CAPTCHA / proof-of-work** only if abuse appears — balance friction vs bots.
// - **WAF / bot management** at the edge for scripted volumetric attacks.
//
// Numbers below are **starting suggestions** for backend config — not enforced here.

/// Suggested defaults for a future API gateway (tune per product / tier).
final class BackendRateLimitGuidelines {
  BackendRateLimitGuidelines._();

  /// Max LLM (or equivalent) invocations per user in a 15-minute sliding window.
  static const int suggestedLlmCallsPer15Minutes = 8;

  /// Max LLM invocations per user per UTC day (free tier).
  static const int suggestedLlmCallsPerDay = 120;

  /// Reject larger prompts at the edge to cap worst-case token usage.
  static const int suggestedMaxPromptCharacters = 2000;

  /// Minimum seconds between two LLM calls for the same user (optional leaky bucket).
  static const int suggestedMinSecondsBetweenCalls = 3;
}

/// Placeholder for a future authenticated HTTP layer. Implement on the server
/// contract you choose (REST, tRPC, etc.); **never** ship provider API keys in-app.
abstract class FutureAccountApi {
  /// Call when your **server** has determined a goal-failure rule triggered.
  Future<void> reportGoalFailureForCurrentUser();

  /// Returns whether the backend says this installation may request LLM/SMS work.
  Future<bool> isAccountInGoodStanding();
}
