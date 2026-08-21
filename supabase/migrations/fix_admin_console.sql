-- =============================================
-- FIX CONSOLE AMMINISTRAZIONE
-- 1. Corregge la policy RLS autoriferita su profiles
--    (causava "infinite recursion detected in policy")
-- 2. Rimuove le funzioni admin_* che scrivevano direttamente
--    su auth.users: su Supabase hosted il ruolo postgres NON ha
--    permessi di scrittura su auth.users, quindi fallivano sempre.
--    La gestione utenti ora passa dall'Edge Function "admin-users"
--    (Admin API con service_role).
-- =============================================

-- =============================================
-- 1. Funzione helper SECURITY DEFINER (bypassa RLS al suo interno,
--    quindi nessuna ricorsione) per verificare il ruolo admin.
-- =============================================
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- =============================================
-- 2. Policy profiles corrette
-- =============================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles_own" ON profiles;
DROP POLICY IF EXISTS "profiles_admin_all" ON profiles;

-- Ognuno legge/aggiorna solo il proprio profilo
CREATE POLICY "profiles_own" ON profiles FOR SELECT USING (auth.uid() = id);

-- Admin: accesso completo ai profili, tramite funzione (niente ricorsione)
CREATE POLICY "profiles_admin_all" ON profiles FOR ALL USING (public.is_admin());

-- Trigger: crea profilo automaticamente al signup.
-- Il blocco EXCEPTION evita che un eventuale fallimento (es. RLS durante
-- la creazione via Admin API) blocchi la creazione dell'utente: per gli
-- utenti creati dalla console ci pensa comunque l'Edge Function a creare
-- il profilo con il ruolo corretto.
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  BEGIN
    INSERT INTO public.profiles (id, role) VALUES (NEW.id, 'membro')
    ON CONFLICT (id) DO NOTHING;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- =============================================
-- 3. Rimozione funzioni RPC rotte (sostituite dall'Edge Function)
-- =============================================
DROP FUNCTION IF EXISTS public.admin_list_users();
DROP FUNCTION IF EXISTS public.admin_create_user(TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.admin_update_user(UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.admin_reset_password(UUID, TEXT);
DROP FUNCTION IF EXISTS public.admin_delete_user(UUID);
