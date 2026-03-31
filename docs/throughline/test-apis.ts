/**
 * Throughline API — Quick Test Script
 * Verifies all APIs are reachable and returning expected responses.
 *
 * Usage:
 *   bun run docs/throughline/test-apis.ts
 */

const BASE = "https://audos.com/api/hooks/execute/workspace-351699";

async function post(endpoint: string, body: object) {
  const r = await fetch(`${BASE}/${endpoint}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  return r.json();
}

// 1. DATABASE: List tables
console.log("1. Testing Database API (list-tables)...");
const tables = await post("db-api", { action: "list-tables" });
console.log(`   Found ${(tables.tables ?? []).length} tables`);

// 2. DATABASE: Insert a test record
console.log("2. Testing Database API (insert)...");
const insert = await post("db-api", {
  action: "insert",
  table: "dashboard_activity",
  data: {
    activity_type: "api_test",
    title: "API Test",
    description: "Test from local coding agent",
    metadata: { source: "off-platform", test: true },
  },
});
console.log(`   Inserted id: ${insert.data?.insertedRows?.[0]?.id ?? "ERROR"}`);

// 3. AI: Generate a short post
console.log("3. Testing AI API...");
const ai = await post("ai-api", {
  action: "generate",
  prompt: "Write a one-sentence tip for podcast hosts",
  systemPrompt: "Be concise and actionable.",
});
console.log(`   Generated: ${ai.text ?? "ERROR"}`);

// 4. CRM: List contacts
console.log("4. Testing CRM API...");
const crm = await post("crm-api", { action: "list", limit: 3 });
console.log(`   Found ${(crm.contacts ?? []).length} contacts`);

// 5. ANALYTICS: Get overview
console.log("5. Testing Analytics API...");
const analytics = await post("analytics-api", { action: "overview", days: 7 });
console.log(`   Total contacts: ${analytics.metrics?.totalContacts ?? "ERROR"}, conversion: ${analytics.metrics?.conversionRate ?? "ERROR"}`);

// 6. WEB: fetch (expects isJsRendered flag on SPA)
console.log("6. Testing Web API (fetch)...");
const webFetch = await post("web-api", {
  action: "fetch",
  url: "https://www.trythroughline.com/",
});
console.log(`   Title: ${webFetch.title ?? "ERROR"}, isJsRendered: ${webFetch.isJsRendered}`);
if (webFetch.warning) console.log(`   ⚠️  ${webFetch.warning}`);

// 7. WEB: metadata (works even on SPAs)
console.log("7. Testing Web API (metadata)...");
const webMeta = await post("web-api", {
  action: "metadata",
  url: "https://www.trythroughline.com/",
});
console.log(`   OG title: ${webMeta.openGraph?.["og:title"] ?? webMeta.title ?? "ERROR"}`);

// 8. WEB: analyze (guest research)
console.log("8. Testing Web API (analyze)...");
const webAnalyze = await post("web-api", {
  action: "analyze",
  url: "https://en.wikipedia.org/wiki/Podcasting",
});
console.log(`   Research title: ${webAnalyze.research?.title ?? "ERROR"}`);
console.log(`   Key topics: ${(webAnalyze.research?.keyTopics ?? []).join(", ") || "none"}`);

console.log("\n✅ All API tests complete!");
