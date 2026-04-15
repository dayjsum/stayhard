#!/usr/bin/env node
/**
 * Local dev stub for STAYHARD_LLM_URL — no dependencies.
 *
 *   node tool/stayhard_llm_stub_server.js
 *
 * Then run Flutter with:
 *   --dart-define=STAYHARD_LLM_URL=http://127.0.0.1:8787/line
 *
 * Android emulator: use http://10.0.2.2:8787/line instead of 127.0.0.1.
 */
const http = require("http");
const PORT = 8787;

http
  .createServer((req, res) => {
    if (req.method === "POST" && req.url === "/line") {
      let body = "";
      req.on("data", (c) => (body += c));
      req.on("end", () => {
        try {
          const j = JSON.parse(body || "{}");
          const title = j.goalTitle || "your task";
          const theme = j.dominantTheme || "general";
          const line = `[stub LLM] ${title} — pattern "${theme}". One rep now beats a perfect plan later.`;
          res.writeHead(200, { "Content-Type": "application/json" });
          res.end(JSON.stringify({ line }));
        } catch (_) {
          res.writeHead(400);
          res.end();
        }
      });
      return;
    }
    res.writeHead(404);
    res.end();
  })
  .listen(PORT, () => {
    console.log(`StayHard LLM stub → POST http://127.0.0.1:${PORT}/line`);
  });
