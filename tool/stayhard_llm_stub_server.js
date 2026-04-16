#!/usr/bin/env node
/**
 * Local dev stub for STAYHARD_LLM_URL — mimics **your API**: in-memory cache + fake line.
 *
 *   node tool/stayhard_llm_stub_server.js
 *
 * Flutter:
 *   --dart-define=STAYHARD_LLM_URL=http://127.0.0.1:8787/line
 *
 * Android emulator: http://10.0.2.2:8787/line
 *
 * Expects `stayhard.line_request.v2` (see RemoteLineGenerator in repo).
 */
const http = require("http");
const PORT = 8787;

/** @type {Map<string, { line: string }>} */
const cache = new Map();

function cacheKey(j) {
  const r = (j.userDeferReason || "").trim().toLowerCase().replace(/\s+/g, " ");
  if (r.length > 0) return `reason:${j.goalId}:${r}`;
  return `fb:${j.deterministicFallbackKey || "none"}`;
}

http
  .createServer((req, res) => {
    if (req.method === "POST" && req.url === "/line") {
      let body = "";
      req.on("data", (c) => (body += c));
      req.on("end", () => {
        try {
          const j = JSON.parse(body || "{}");
          if (j.schema !== "stayhard.line_request.v2") {
            res.writeHead(400);
            res.end(JSON.stringify({ error: "expected schema stayhard.line_request.v2" }));
            return;
          }
          const key = cacheKey(j);
          const hit = cache.get(key);
          if (hit) {
            res.writeHead(200, { "Content-Type": "application/json" });
            res.end(JSON.stringify({ line: hit.line, cached: true }));
            return;
          }
          const title = j.goalTitle || "your task";
          const theme = j.dominantTheme || "general";
          const reason = j.userDeferReason ? ` (they said: ${j.userDeferReason})` : "";
          const line = `[stub API] ${title} — theme "${theme}"${reason}. Same key will hit cache.`;
          cache.set(key, { line });
          res.writeHead(200, { "Content-Type": "application/json" });
          res.end(JSON.stringify({ line, cached: false }));
        } catch (e) {
          res.writeHead(400);
          res.end(JSON.stringify({ error: String(e) }));
        }
      });
      return;
    }
    res.writeHead(404);
    res.end();
  })
  .listen(PORT, () => {
    console.log(`StayHard API stub → POST http://127.0.0.1:${PORT}/line (v2 + cache)`);
  });
