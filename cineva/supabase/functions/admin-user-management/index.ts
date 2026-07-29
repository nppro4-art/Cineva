import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const authHeader = req.headers.get('Authorization') ?? '';

    const authed = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const {
      data: { user },
      error: authError,
    } = await authed.auth.getUser();

    if (authError || !user) {
      return json({ error: 'UNAUTHORIZED' }, 401);
    }

    const { data: profile } = await authed.from('profiles').select('role').eq('id', user.id).maybeSingle();
    if (!profile || profile.role !== 'admin') {
      return json({ error: 'FORBIDDEN' }, 403);
    }

    const admin = createClient(supabaseUrl, serviceRoleKey);
    const body = await req.json();
    const action = body.action as string | undefined;

    if (!['create', 'update', 'delete'].includes(action ?? '')) {
      return json({ error: 'UNKNOWN_ACTION' }, 400);
    }

    if (action === 'create') {
      const email = String(body.email ?? '').trim().toLowerCase();
      const password = String(body.password ?? '');
      const fullName = String(body.fullName ?? '').trim();
      const role = sanitizeRole(body.role);
      const expiresAt = parseOptionalIso(body.expiresAt);

      if (!isValidEmail(email)) return json({ error: 'INVALID_EMAIL' }, 400);
      if (password.length < 6) return json({ error: 'WEAK_PASSWORD' }, 400);
      if (fullName.length < 2) return json({ error: 'INVALID_FULL_NAME' }, 400);

      const { data, error } = await admin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { full_name: fullName, role },
      });
      if (error || !data.user) {
        return json({ error: error?.message ?? 'CREATE_FAILED' }, 400);
      }

      await admin.from('profiles').update({
        email,
        full_name: fullName,
        role,
        status: 'active',
        subscription_expires_at: expiresAt,
      }).eq('id', data.user.id);

      return json({ ok: true, userId: data.user.id });
    }

    if (action === 'update') {
      const userId = String(body.userId ?? '');
      const email = String(body.email ?? '').trim().toLowerCase();
      const fullName = String(body.fullName ?? '').trim();
      const role = sanitizeRole(body.role);
      const status = sanitizeStatus(body.status);
      const expiresAt = parseOptionalIso(body.expiresAt);

      if (!isValidUuid(userId)) return json({ error: 'INVALID_USER_ID' }, 400);
      if (!isValidEmail(email)) return json({ error: 'INVALID_EMAIL' }, 400);
      if (fullName.length < 2) return json({ error: 'INVALID_FULL_NAME' }, 400);

      const { error } = await admin.auth.admin.updateUserById(userId, {
        email,
        user_metadata: { full_name: fullName, role },
      });
      if (error) {
        return json({ error: error.message }, 400);
      }

      await admin.from('profiles').update({
        email,
        full_name: fullName,
        role,
        status,
        subscription_expires_at: expiresAt,
      }).eq('id', userId);

      return json({ ok: true });
    }

    if (action === 'delete') {
      const userId = String(body.userId ?? '');
      if (!isValidUuid(userId)) return json({ error: 'INVALID_USER_ID' }, 400);
      const { error } = await admin.auth.admin.deleteUser(userId);
      if (error) {
        return json({ error: error.message }, 400);
      }
      return json({ ok: true });
    }

  } catch (error) {
    return json({ error: String(error) }, 500);
  }
});

function isValidEmail(value: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

function isValidUuid(value: string) {
  return /^[0-9a-fA-F-]{36}$/.test(value);
}

function sanitizeRole(value: unknown) {
  return value === 'admin' ? 'admin' : 'user';
}

function sanitizeStatus(value: unknown) {
  return value === 'suspended' ? 'suspended' : 'active';
}

function parseOptionalIso(value: unknown) {
  if (!value) return null;
  const raw = String(value);
  const parsed = new Date(raw);
  if (Number.isNaN(parsed.getTime())) {
    throw new Error('INVALID_DATE');
  }
  return raw;
}

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
}
