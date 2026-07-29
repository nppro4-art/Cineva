import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

export async function loadTokens(
  admin: ReturnType<typeof createClient>,
  userId: string | null,
) {
  let query = admin.from('devices').select('push_token');
  if (userId) query = query.eq('user_id', userId);
  const { data } = await query.not('push_token', 'is', null);
  return (data ?? [])
    .map((row) => row.push_token as string | null)
    .filter((value): value is string => Boolean(value));
}

export function extractInvalidTokens(
  tokens: string[],
  results: Array<Record<string, unknown>>,
) {
  const invalidErrors = new Set([
    'InvalidRegistration',
    'NotRegistered',
    'registration-token-not-registered',
  ]);

  return results
    .map((result, index) => ({
      error: result?.error as string | undefined,
      token: tokens[index],
    }))
    .filter((entry) => entry.error && invalidErrors.has(entry.error))
    .map((entry) => entry.token);
}
