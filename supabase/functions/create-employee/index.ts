import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from 'jsr:@supabase/supabase-js@2';

const MIN_PASSWORD = 8;

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: cors() });
  }
  try {
    const url = Deno.env.get('SUPABASE_URL')!;
    const anon = Deno.env.get('SUPABASE_ANON_KEY')!;
    const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const userClient = createClient(url, anon, {
      global: {
        headers: { Authorization: req.headers.get('Authorization') ?? '' },
      },
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
      return json({ error: 'Solo staff puede gestionar personal' }, 403);
    }

    const body = await req.json();
    const documento = String(body.documento ?? '').trim();
    const correo = String(body.correo ?? '').trim();
    const password = String(body.password ?? '').trim();
    const existingId = String(body.id ?? '').trim();
    const rol = String(body.rol ?? 'empleado');
    if (!documento) return json({ error: 'Documento requerido' }, 400);
    if (rol === 'super_admin' && actor.rol !== 'super_admin') {
      return json({ error: 'Solo Super Admin puede asignar ese rol' }, 403);
    }

    const profilePayload = {
      documento,
      nombre: body.nombre,
      apellido: body.apellido,
      cargo: body.cargo,
      correo,
      rh: body.rh,
      eps: body.eps,
      arl: body.arl,
      rol,
      activo: body.activo !== false,
      location_id: body.location_id ?? '11111111-1111-1111-1111-111111111111',
      shift_id: body.shift_id ?? '22222222-2222-2222-2222-222222222222',
    };

    if (existingId) {
      if (password && password.length < MIN_PASSWORD) {
        return json({ error: `Contraseña de al menos ${MIN_PASSWORD} caracteres` }, 400);
      }
      if (password) {
        const { error: passErr } = await admin.auth.admin.updateUserById(
          existingId,
          { password, app_metadata: { rol } },
        );
        if (passErr) return json({ error: passErr.message }, 400);
      } else {
        await admin.auth.admin.updateUserById(existingId, {
          app_metadata: { rol },
        });
      }
      const { error: updErr } = await admin
        .from('profiles')
        .update(profilePayload)
        .eq('id', existingId);
      if (updErr) return json({ error: updErr.message }, 400);
      return json({ id: existingId });
    }

    if (password.length < MIN_PASSWORD) {
      return json(
        { error: `Contraseña de al menos ${MIN_PASSWORD} caracteres` },
        400,
      );
    }

    const email = `${documento}@users.attcontrol.local`;
    const { data: created, error: createErr } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      app_metadata: { rol },
      user_metadata: { correo },
    });
    if (createErr || !created.user) {
      return json({ error: createErr?.message ?? 'No se pudo crear el usuario' }, 400);
    }

    const { error: upsertErr } = await admin.from('profiles').upsert({
      id: created.user.id,
      ...profilePayload,
    });
    if (upsertErr) {
      await admin.auth.admin.deleteUser(created.user.id);
      return json({ error: upsertErr.message }, 400);
    }
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
