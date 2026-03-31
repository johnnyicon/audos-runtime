/**
 * Audos Runtime API — Quick Test Script
 * Verifies all APIs are reachable and returning expected responses.
 *
 * Usage:
 *   bun run docs/audos-api/test-apis.ts
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
console.log("1. Testing Database API...");
const tables = await post("db-api", { action: "list-tables" });
console.log(`   Found ${(tables.tables ?? []).length} tables`);

// 2. DATABASE: Insert a test record
console.log("2. Inserting test record...");
const insert = await post("db-api", {
  action: "insert",
  table: "dashboard_activity",
  data: {
    activity_type: "api_test",
    description: "Test from local coding agent",
    metadata: { source: "off-platform", test: true },
  },
});
console.log(`   Insert result:`, insert);

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
console.log(`   Analytics:`, analytics);

// 6. WEB: Fetch a page
console.log("6. Testing Web API...");
const web = await post("web-api", {
  action: "fetch",
  url: "https://www.trythroughline.com/",
});
console.log(`   Fetched page, content length: ${web.contentLength ?? 0} chars`);

console.log("\n✅ All API tests complete!");
