import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from 'jsr:@supabase/supabase-js@2';

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: cors() });
  }
  try {
    const { identifier, password } = await req.json();
    if (!identifier || !password) {
      return json({ error: 'Faltan credenciales' }, 400);
    }

    const url = Deno.env.get('SUPABASE_URL')!;
    const anon = Deno.env.get('SUPABASE_ANON_KEY')!;
    const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const admin = createClient(url, service);
    const raw = String(identifier).trim();

    let query = admin.from('profiles').select('id, documento, correo');
    query = raw.includes('@')
      ? query.ilike('correo', raw)
      : query.eq('documento', raw);
    const { data: profile, error } = await query.maybeSingle();
    if (error || !profile) {
      return json({ error: 'Usuario no encontrado' }, 401);
    }

    const email = `${profile.documento}@users.attcontrol.local`;
    const auth = createClient(url, anon);
    const { data, error: signErr } = await auth.auth.signInWithPassword({
      email,
      password,
    });
    if (signErr || !data.session) {
      return json({ error: 'Contraseña incorrecta' }, 401);
    }
    return json({
      access_token: data.session.access_token,
      refresh_token: data.session.refresh_token,
      user_id: data.user?.id,
    });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function cors() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers':
      'authorization, x-client-info, apikey, content-type',
  };
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors(), 'Content-Type': 'application/json' },
  });
}
