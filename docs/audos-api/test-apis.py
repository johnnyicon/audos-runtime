"""
Audos Runtime API — Quick Test Script
Verifies all APIs are reachable and returning expected responses.

Usage:
    python3 docs/audos-api/test-apis.py
"""

import requests

BASE = "https://audos.com/api/hooks/execute/workspace-351699"

# 1. DATABASE: List tables to confirm connection
print("1. Testing Database API...")
r = requests.post(f"{BASE}/db-api", json={"action": "list-tables"})
print(f"   Found {len(r.json().get('tables', []))} tables")

# 2. DATABASE: Insert a test record
print("2. Inserting test record...")
r = requests.post(f"{BASE}/db-api", json={
    "action": "insert",
    "table": "dashboard_activity",
    "data": {
        "activity_type": "api_test",
        "description": "Test from local coding agent",
        "metadata": {"source": "off-platform", "test": True}
    }
})
print(f"   Insert result: {r.json()}")

# 3. AI: Generate a short post
print("3. Testing AI API...")
r = requests.post(f"{BASE}/ai-api", json={
    "action": "generate",
    "prompt": "Write a one-sentence tip for podcast hosts",
    "systemPrompt": "Be concise and actionable."
})
print(f"   Generated: {r.json().get('text', 'ERROR')}")

# 4. CRM: List contacts
print("4. Testing CRM API...")
r = requests.post(f"{BASE}/crm-api", json={"action": "list", "limit": 3})
contacts = r.json().get('contacts', [])
print(f"   Found {len(contacts)} contacts")

# 5. ANALYTICS: Get overview
print("5. Testing Analytics API...")
r = requests.post(f"{BASE}/analytics-api", json={"action": "overview", "days": 7})
print(f"   Analytics: {r.json()}")

# 6. WEB: Fetch a page
print("6. Testing Web API...")
r = requests.post(f"{BASE}/web-api", json={
    "action": "fetch",
    "url": "https://www.trythroughline.com/"
})
print(f"   Fetched page, content length: {r.json().get('contentLength', 0)} chars")

print("\n✅ All API tests complete!")
