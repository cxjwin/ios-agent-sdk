// TODO: implement WebSearchTool (+ companion FetchURLTool).
//
// Design notes from the 2026-05-16 discussion — capture before they rot:
//
// PROVIDER CHOICE
//   Primary candidate: Brave Search API.
//     - independent index, 2000 free queries/month, privacy-friendly
//     - returns clean JSON; we pick top-N and format snippets ourselves
//     - long-term cheapest sustainable option
//   Alt candidate: Tavily.
//     - purpose-built for LLM agents, returns pre-summarized `answer` + sources
//     - fastest to a working demo; adds a third-party dep on top of the search index
//   Considered and rejected for the *primary* path:
//     - Google Custom Search JSON API — stable but $5/1k, CSE setup overhead
//     - Anthropic server-side web_search — zero code, but bypasses this SDK's
//       harness (no AgentEvents, locks us to one provider) — conflicts with the
//       multi-provider story
//     - Exa — semantic search, niche use case
//     - DuckDuckGo Instant Answer — no general web results
//     - WKWebView scraping — brittle + ToS issues
//
// SHAPE
//   struct WebSearchTool: ToolProtocol
//     init(apiKey: String, urlSession: URLSession = .shared, maxResults: Int = 5)
//     name = "web_search"
//     isReadOnly = true
//     inputSchema:
//       - query: String (required)
//       - maxResults: Int? (default 5)
//       - freshness: String? ("day" | "week" | "month" | "year")
//       - country: String? (ISO-3166-1 alpha-2)
//     execute: GET → parse JSON → return markdown string the LLM can chew on:
//       1. **Title**
//          https://url
//          One-line snippet.
//
// COMPANION TOOL
//   Search results only tell the agent "this page exists." Real answers need a
//   FetchURLTool that pulls the HTML and returns plain text. Sketch:
//     - GET the URL with a short timeout (5s) + size cap (e.g. 1 MB)
//     - strip tags via NSAttributedString(data:options:.html) or a small regex
//       readability pass; return first ~8 KB of text
//     - obey robots.txt? probably not worth it for an agent tool; document it
//   Decide on a per-tool budget knob (maxTextBytes) so the model can't blow
//   the context window on one fetch.
//
// ERROR HANDLING
//   Return error strings, do NOT throw. The LLM can read "rate limited, retry
//   in 60s" or "no results" and adjust. Throwing only makes sense for bugs in
//   our own code.
//
// TESTING
//   Mock URLProtocol so tests don't hit the network. Cover: happy path,
//   429, empty result set, non-2xx, malformed JSON, oversized response.
