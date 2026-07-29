import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { extractInvalidTokens, loadTokens } from '../_shared/fcm.ts';

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
    const serverKey = Deno.env.get('FCM_SERVER_KEY');

    if (!serverKey) {
      return json({ error: 'FCM_SERVER_KEY_MISSING' }, 500);
    }

    const authed = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const {
      data: { user },
    } = await authed.auth.getUser();

    if (!user) return json({ error: 'UNAUTHORIZED' }, 401);

    const { data: profile } = await authed.from('profiles').select('role').eq('id', user.id).maybeSingle();
    if (!profile || profile.role !== 'admin') return json({ error: 'FORBIDDEN' }, 403);

    const admin = createClient(supabaseUrl, serviceRoleKey);
    const body = await req.json();
    const title = String(body.title ?? '').trim();
    const message = String(body.body ?? '').trim();
    const channel = String(body.channel ?? 'general');
    const targetUserId = body.userId ? String(body.userId) : null;
    const scheduledAt = parseOptionalIso(body.scheduledAt);
    const contentId = body.contentId ? String(body.contentId) : null;
    const screen = body.screen ? String(body.screen) : null;

    if (title.length < 2) return json({ error: 'INVALID_TITLE' }, 400);
    if (message.length < 2) return json({ error: 'INVALID_BODY' }, 400);
    if (targetUserId && !isValidUuid(targetUserId)) return json({ error: 'INVALID_USER_ID' }, 400);

    const status = scheduledAt ? 'scheduled' : 'draft';

    const { data: inserted, error: insertError } = await admin
      .from('notifications')
      .insert({
        user_id: targetUserId,
        title,
        body: message,
        channel,
        status,
        scheduled_at: scheduledAt,
        payload: {
          contentId,
          screen,
        },
        created_by: user.id,
      })
      .select()
      .single();

    if (insertError || !inserted) {
      return json({ error: insertError?.message ?? 'INSERT_FAILED' }, 400);
    }

    if (scheduledAt) {
      return json({ ok: true, notificationId: inserted.id, status: 'scheduled' });
    }

    const tokens = await loadTokens(admin, targetUserId);
    if (tokens.length === 0) {
      await admin.from('notifications').update({ status: 'failed' }).eq('id', inserted.id);
      return json({ error: 'NO_TOKENS', notificationId: inserted.id }, 400);
    }

    const payload = {
      registration_ids: tokens,
      priority: 'high',
      notification: {
        title,
        body: message,
      },
      data: {
        contentId,
        screen,
        notificationId: inserted.id,
      },
    };

    const response = await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: {
        Authorization: `key=${serverKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    });

    const responseBody = await response.text();
    let invalidTokens: string[] = [];
    try {
      const parsed = JSON.parse(responseBody);
      invalidTokens = extractInvalidTokens(tokens, parsed?.results ?? []);
      if (invalidTokens.length > 0) {
        await admin.from('devices').update({ push_token: null }).in('push_token', invalidTokens);
      }
    } catch (_) {}

    await admin
      .from('notifications')
      .update({
        status: response.ok ? 'sent' : 'failed',
        sent_at: response.ok ? new Date().toISOString() : null,
        payload: {
          contentId,
          screen,
          invalidTokens,
          fcmResponse: responseBody,
        },
      })
      .eq('id', inserted.id);

    return json({ ok: response.ok, notificationId: inserted.id, response: responseBody, invalidTokens }, response.ok ? 200 : 500);
  } catch (error) {
    return json({ error: String(error) }, 500);
  }
});

function isValidUuid(value: string) {
  return /^[0-9a-fA-F-]{36}$/.test(value);
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
