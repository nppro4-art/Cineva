import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { extractInvalidTokens, loadTokens } from '../_shared/fcm.ts';

Deno.serve(async (req) => {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const serverKey = Deno.env.get('FCM_SERVER_KEY');
  const cronSecret = Deno.env.get('CRON_SECRET');

  if (!serverKey) {
    return new Response(JSON.stringify({ error: 'FCM_SERVER_KEY_MISSING' }), { status: 500 });
  }
  if (!cronSecret) {
    return new Response(JSON.stringify({ error: 'CRON_SECRET_MISSING' }), { status: 500 });
  }
  if (req.headers.get('x-cron-secret') !== cronSecret) {
    return new Response(JSON.stringify({ error: 'FORBIDDEN' }), { status: 403 });
  }

  const admin = createClient(supabaseUrl, serviceRoleKey);
  const now = new Date().toISOString();
  const { data: notifications } = await admin
    .from('notifications')
    .select()
    .eq('status', 'scheduled')
    .lte('scheduled_at', now)
    .limit(50);

  for (const notification of notifications ?? []) {
    const tokens = await loadTokens(admin, notification.user_id as string | null);
    if (tokens.length === 0) {
      await admin.from('notifications').update({ status: 'failed' }).eq('id', notification.id);
      continue;
    }

    const payload = {
      registration_ids: tokens,
      priority: 'high',
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: {
        ...(notification.payload ?? {}),
        notificationId: notification.id,
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
          ...(notification.payload ?? {}),
          invalidTokens,
          fcmResponse: responseBody,
        },
      })
      .eq('id', notification.id);
  }

  return new Response(JSON.stringify({ ok: true, processed: (notifications ?? []).length }), { status: 200 });
});

