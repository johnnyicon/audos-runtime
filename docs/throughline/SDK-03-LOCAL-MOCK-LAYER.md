# Audos Local Mock Layer

This file provides a mock layer that lets you develop locally while calling the real Audos backend APIs. Your local app will **function identically** to the deployed version — only the visual theming will differ.

## Project Structure

```
throughline/
├── src/
│   ├── lib/
│   │   ├── audos-api.ts         # REST API client
│   │   ├── audos-hooks.ts       # React hooks (wrap APIs)
│   │   └── audos-config.ts      # Configuration
│   ├── components/
│   │   └── ui/                  # ShadCN components (copy here)
│   ├── apps/
│   │   ├── Home.tsx             # Your app code
│   │   ├── Briefing.tsx         # Your app code
│   │   ├── Signature.tsx        # Your app code
│   │   ├── Studio.tsx           # Your app code
│   │   └── Setup.tsx            # Your app code
│   └── App.tsx                # Main app with local navigation
├── tailwind.config.js
├── vite.config.ts
└── package.json
```

---

## File 1: `src/lib/audos-config.ts`

```typescript
// Audos Configuration
// Update these values for your workspace

export const AUDOS_CONFIG = {
  // Your workspace ID
  WORKSPACE_ID: '8f1ad824-832f-4af8-b77e-ab931a250625',
  
  // API base URL - use your custom domain or audos.app
  API_BASE: 'https://trythroughline.com',
  
  // Local development settings
  LOCAL_MODE: process.env.NODE_ENV !== 'production',
  
  // Default branding for local dev (optional - or fetch from API)
  BRANDING: {
    name: 'Throughline',
    primaryColor: '#6366F1',
    secondaryColor: '#EF4444',
    logo: '/logo.svg'
  }
} as const;
```

---

## File 2: `src/lib/audos-api.ts`

```typescript
// Audos REST API Client
// This works from local dev, deployed apps, or external services

import { AUDOS_CONFIG } from './audos-config';

const { WORKSPACE_ID, API_BASE } = AUDOS_CONFIG;

// ===============================================================
// Base API Caller
// ===============================================================

async function callHook(hookName: string, body: any): Promise<any> {
  const response = await fetch(
    `${API_BASE}/api/hooks/execute/workspace-${WORKSPACE_ID}/${hookName}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body)
    }
  );
  
  if (!response.ok) {
    throw new Error(`API error: ${response.status} ${response.statusText}`);
  }
  
  return response.json();
}

// ===============================================================
// Database API
// ===============================================================

export type FilterOperator = 'eq' | 'neq' | 'gt' | 'gte' | 'lt' | 'lte' | 'like' | 'ilike' | 'in' | 'is_null' | 'not_null';

export interface Filter {
  column: string;
  operator: FilterOperator;
  value?: any;
}

export interface QueryOptions {
  filters?: Filter[];
  orderBy?: { column: string; direction?: 'asc' | 'desc' };
  limit?: number;
  offset?: number;
}

export const db = {
  // List all tables in the workspace
  async listTables() {
    return callHook('db-api', { action: 'list-tables' });
  },

  // Describe a table's schema
  async describe(table: string) {
    return callHook('db-api', { action: 'describe', table });
  },

  // Query data from a table
  async query<T = any>(table: string, options: QueryOptions = {}): Promise<{ success: boolean; data: { rows: T[]; rowCount: number } }> {
    return callHook('db-api', { action: 'query', table, ...options });
  },

  // Insert rows into a table
  async insert(table: string, rows: any[]) {
    return callHook('db-api', { action: 'insert', table, rows });
  },

  // Update rows in a table
  async update(table: string, filters: Filter[], data: any) {
    return callHook('db-api', { action: 'update', table, filters, data });
  },

  // Delete rows from a table
  async delete(table: string, filters: Filter[]) {
    return callHook('db-api', { action: 'delete', table, filters });
  }
};

// ===============================================================
// AI API
// ===============================================================

export const ai = {
  // Generate text using AI
  async generate(prompt: string, system?: string): Promise<{ success: boolean; text: string; usage: any }> {
    return callHook('ai-api', { action: 'generate', prompt, system });
  }
};

// ===============================================================
// Email API
// ===============================================================

export const email = {
  // Send an email
  async send(options: { to: string; subject: string; text: string; html?: string; replyTo?: string }) {
    return callHook('email-api', { action: 'send', ...options });
  }
};

// ===============================================================
// Web API
// ===============================================================

export const web = {
  // Fetch and parse a web page
  async fetch(url: string): Promise<{ success: boolean; content: string; title: string }> {
    return callHook('web-api', { action: 'fetch', url });
  }
};

// ===============================================================
// Storage API
// ===============================================================

export const storage = {
  // List files
  async list(category?: string) {
    return callHook('storage-api', { action: 'list', category });
  },

  // Upload a file
  async upload(filename: string, content: string, contentType: string) {
    return callHook('storage-api', { action: 'upload', filename, content, contentType });
  }
};

// ===============================================================
// Analytics API
// ===============================================================

export const analytics = {
  // Get overview metrics
  async overview(days: number = 30) {
    return callHook('analytics-api', { action: 'overview', days });
  }
};

// ===============================================================
// CRM API
// ===============================================================

export const crm = {
  // List contacts
  async listContacts(limit: number = 50) {
    return callHook('crm-api', { action: 'list-contacts', limit });
  },

  // Create a contact
  async createContact(contact: { email: string; name?: string; source?: string }) {
    return callHook('crm-api', { action: 'create-contact', ...contact });
  }
};

export { callHook };
```

---

## File 3: `src/lib/audos-hooks.ts`

```typescript
// React Hooks that wrap the Audos APIs
// These provide a similar interface to the platform hooks

import { useState, useEffect, useCallback } from 'react';
import { db, QueryOptions, Filter } from './audos-api';
import { AUDOS_CONFIG } from './audos-config';

// ===============================================================
// useWorkspaceDB - Database hook
// ===============================================================

export function useWorkspaceDB<T = any>(table: string) {
  const [data, setData] = useState<T[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  const query = useCallback(async (options: QueryOptions = {}) => {
    setLoading(true);
    setError(null);
    try {
      const result = await db.query<T>(table, options);
      if (result.success) {
        setData(result.data.rows);
        return result.data.rows;
      }
      throw new Error('Query failed');
    } catch (e) {
      setError(e as Error);
      throw e;
    } finally {
      setLoading(false);
    }
  }, [table]);

  const insert = useCallback(async (rows: Partial<T>[]) => {
    const result = await db.insert(table, rows);
    return result;
  }, [table]);

  const update = useCallback(async (filters: Filter[], updateData: Partial<T>) => {
    const result = await db.update(table, filters, updateData);
    return result;
  }, [table]);

  const remove = useCallback(async (filters: Filter[]) => {
    const result = await db.delete(table, filters);
    return result;
  }, [table]);

  return {
    data,
    loading,
    error,
    query,
    insert,
    update,
    remove
  };
}

// ===============================================================
// useBranding - Brand colors, logo, etc.
// ===============================================================

export function useBranding() {
  // In local dev, return config values
  // On platform, this would be injected by the runtime
  return {
    name: AUDOS_CONFIG.BRANDING.name,
    primaryColor: AUDOS_CONFIG.BRANDING.primaryColor,
    secondaryColor: AUDOS_CONFIG.BRANDING.secondaryColor,
    logo: AUDOS_CONFIG.BRANDING.logo,
    colors: {
      primary: AUDOS_CONFIG.BRANDING.primaryColor,
      secondary: AUDOS_CONFIG.BRANDING.secondaryColor
    }
  };
}

// ===============================================================
// useSession - Visitor session (mocked locally)
// ===============================================================

export function useSession() {
  const [session, setSession] = useState(() => {
    // Check localStorage for existing session
    const stored = localStorage.getItem('audos-session');
    if (stored) {
      return JSON.parse(stored);
    }
    return {
      id: `local-${Date.now()}`,
      email: null,
      name: null
    };
  });

  const setEmail = useCallback((email: string, name?: string) => {
    const updated = { ...session, email, name: name || session.name };
    setSession(updated);
    localStorage.setItem('audos-session', JSON.stringify(updated));
  }, [session]);

  return {
    ...session,
    setEmail,
    isAuthenticated: !!session.email
  };
}

// ===============================================================
// useSpaceFiles - JSON file storage (localStorage fallback)
// ===============================================================

export function useSpaceFiles<T = any>(filename: string, defaultValue: T = {} as T) {
  const [data, setData] = useState<T>(() => {
    const stored = localStorage.getItem(`audos-file-${filename}`);
    return stored ? JSON.parse(stored) : defaultValue;
  });

  const save = useCallback((newData: T) => {
    setData(newData);
    localStorage.setItem(`audos-file-${filename}`, JSON.stringify(newData));
  }, [filename]);

  return { data, save };
}
```

---

## Usage Examples

### Using the Database Hook

```tsx
import { useWorkspaceDB } from '../lib/audos-hooks';

interface VoiceProfile {
  id: number;
  name: string;
  type: 'host' | 'brand';
  description: string;
}

function VoiceProfiles() {
  const { data, loading, query, insert } = useWorkspaceDB<VoiceProfile>('voice_profiles');

  useEffect(() => {
    query({ limit: 10 });
  }, []);

  const addProfile = async () => {
    await insert([{ name: 'New Profile', type: 'host', description: '' }]);
    query(); // Refresh
  };

  if (loading) return <div>Loading...</div>;

  return (
    <div>
      {data.map(profile => (
        <div key={profile.id}>{profile.name}</div>
      ))}
      <button onClick={addProfile}>Add Profile</button>
    </div>
  );
}
```

### Using the API Directly (with TanStack Query)

```tsx
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { db } from '../lib/audos-api';

function VoiceProfilesTanStack() {
  const queryClient = useQueryClient();

  const { data, isLoading } = useQuery({
    queryKey: ['voice_profiles'],
    queryFn: () => db.query('voice_profiles', { limit: 10 })
  });

  const addMutation = useMutation({
    mutationFn: (profile) => db.insert('voice_profiles', [profile]),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['voice_profiles'] })
  });

  if (isLoading) return <div>Loading...</div>;

  return (
    <div>
      {data?.data?.rows.map(profile => (
        <div key={profile.id}>{profile.name}</div>
      ))}
    </div>
  );
}
```