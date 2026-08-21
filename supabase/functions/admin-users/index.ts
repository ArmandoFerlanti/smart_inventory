// Edge Function: admin-users
// Gestisce utenti e ruoli tramite la Admin API (service_role).
// Verifica che il chiamante sia un utente con ruolo 'admin' nella tabella profiles.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return json({ error: 'Token mancante' }, 401);
    }

    // Client con il JWT dell'utente chiamante: serve a verificare chi sia.
    const userClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();
    if (userError || !user) {
      return json({ error: 'Non autenticato' }, 401);
    }

    const { data: profile, error: profileError } = await userClient
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .maybeSingle();
    if (profileError) {
      return json({ error: `Errore profilo: ${profileError.message}` }, 500);
    }
    if (profile?.role !== 'admin') {
      return json({ error: 'Solo gli amministratori possono eseguire questa operazione' }, 403);
    }

    // Client service_role per le operazioni amministrative.
    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      { auth: { autoRefreshToken: false, persistSession: false } },
    );

    const body = await req.json();
    const action = body.action as string;

    switch (action) {
      case 'list': {
        const { data, error } = await admin.auth.admin.listUsers();
        if (error) return json({ error: error.message }, 500);

        const users = await Promise.all(
          data.users.map(async (u) => {
            const { data: p } = await admin
              .from('profiles')
              .select('role')
              .eq('id', u.id)
              .maybeSingle();
            return {
              id: u.id,
              email: u.email,
              role: p?.role ?? 'membro',
              created_at: u.created_at,
            };
          }),
        );
        return json({ users });
      }

      case 'create': {
        const email = String(body.email ?? '').trim();
        const password = String(body.password ?? '');
        const role = ['admin', 'presidente', 'membro'].includes(body.role)
          ? body.role
          : 'membro';

        if (!email.includes('@')) {
          return json({ error: 'Email non valida' }, 400);
        }
        if (password.length < 6) {
          return json({ error: 'La password deve avere almeno 6 caratteri' }, 400);
        }

        const { data, error } = await admin.auth.admin.createUser({
          email,
          password,
          email_confirm: true,
        });
        if (error) return json({ error: error.message }, 400);

        // Il trigger on_auth_user_created crea già il profilo come 'membro';
        // l'upsert allinea il ruolo richiesto anche in assenza del trigger.
        const { error: upsertError } = await admin
          .from('profiles')
          .upsert({ id: data.user.id, role });
        if (upsertError) {
          return json({ error: `Utente creato ma ruolo non assegnato: ${upsertError.message}` }, 500);
        }

        return json({ id: data.user.id });
      }

      case 'update': {
        const userId = String(body.userId ?? '');
        const email = String(body.email ?? '').trim();
        const role = ['admin', 'presidente', 'membro'].includes(body.role)
          ? body.role
          : null;

        if (!userId) return json({ error: 'ID utente mancante' }, 400);
        if (!email.includes('@')) {
          return json({ error: 'Email non valida' }, 400);
        }

        // Sicurezza: un admin non può retrocedere se stesso
        // (evita di rimanere senza alcun amministratore).
        if (userId === user.id && role !== 'admin') {
          return json({ error: 'Non puoi modificare il tuo stesso ruolo da admin' }, 400);
        }

        const { error: updateError } = await admin.auth.admin.updateUserById(
          userId,
          { email },
        );
        if (updateError) return json({ error: updateError.message }, 400);

        if (role) {
          const { error: roleError } = await admin
            .from('profiles')
            .update({ role })
            .eq('id', userId);
          if (roleError) {
            return json({ error: `Email aggiornata ma ruolo non modificato: ${roleError.message}` }, 500);
          }
        }

        return json({ ok: true });
      }

      case 'reset_password': {
        const userId = String(body.userId ?? '');
        const password = String(body.password ?? '');

        if (!userId) return json({ error: 'ID utente mancante' }, 400);
        if (password.length < 6) {
          return json({ error: 'La password deve avere almeno 6 caratteri' }, 400);
        }

        const { error } = await admin.auth.admin.updateUserById(userId, {
          password,
        });
        if (error) return json({ error: error.message }, 400);

        return json({ ok: true });
      }

      case 'delete': {
        const userId = String(body.userId ?? '');
        if (!userId) return json({ error: 'ID utente mancante' }, 400);

        if (userId === user.id) {
          return json({ error: 'Non puoi eliminare il tuo stesso account' }, 400);
        }

        const { error } = await admin.auth.admin.deleteUser(userId);
        if (error) return json({ error: error.message }, 400);

        return json({ ok: true });
      }

      default:
        return json({ error: 'Azione non valida' }, 400);
    }
  } catch (e) {
    console.error('admin-users error:', e);
    return json({ error: e?.message ?? String(e) }, 500);
  }
});
