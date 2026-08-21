import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from 'jsr:@supabase/supabase-js@2';

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: cors() });
  }
  try {
    const url = Deno.env.get('SUPABASE_URL')!;
    const anon = Deno.env.get('SUPABASE_ANON_KEY')!;
    const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const userClient = createClient(url, anon, {
      global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
    });
    const { data: userData, error: userErr } = await userClient.auth.getUser();
    if (userErr || !userData.user) {
      return json({ error: 'No autorizado' }, 401);
    }

    const admin = createClient(url, service);
    const { data: actor } = await admin
      .from('profiles')
      .select('rol')
      .eq('id', userData.user.id)
      .maybeSingle();
    if (!actor || !['super_admin', 'supervisor'].includes(actor.rol)) {
      return json({ error: 'Solo staff puede crear personal' }, 403);
    }

    const body = await req.json();
    const documento = String(body.documento ?? '').trim();
    const correo = String(body.correo ?? '').trim();
    const password = String(body.password ?? 'AttControl2026!');
    if (!documento) return json({ error: 'Documento requerido' }, 400);

    const email = `${documento}@users.attcontrol.local`;
    const { data: created, error: createErr } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      app_metadata: { rol: body.rol ?? 'empleado' },
      user_metadata: { correo },
    });
    if (createErr || !created.user) {
      return json({ error: createErr?.message ?? 'No se pudo crear el usuario' }, 400);
    }

    const { error: upsertErr } = await admin.from('profiles').upsert({
      id: created.user.id,
      documento,
      nombre: body.nombre,
      apellido: body.apellido,
      cargo: body.cargo,
      correo,
      rh: body.rh,
      eps: body.eps,
      arl: body.arl,
      rol: body.rol ?? 'empleado',
      activo: body.activo ?? true,
    });
    if (upsertErr) return json({ error: upsertErr.message }, 400);
    return json({ id: created.user.id });
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
