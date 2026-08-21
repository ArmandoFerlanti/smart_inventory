-- =============================================
-- ROLES, CARDS PRESIDENTI, ADMIN FUNCTIONS
-- =============================================

-- =============================================
-- 1. TABELLA PROFILES CON RUOLI
-- =============================================
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'membro' CHECK (role IN ('admin', 'presidente', 'membro')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Trigger: crea profilo automaticamente al signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, role) VALUES (NEW.id, 'membro');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- RLS profiles
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "profiles_own" ON profiles;
DROP POLICY IF EXISTS "profiles_admin_all" ON profiles;
CREATE POLICY "profiles_own" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "profiles_admin_all" ON profiles FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- =============================================
-- 2. TABELLA CARDS PRESIDENTI
-- =============================================
CREATE TABLE IF NOT EXISTS cards_presidenti (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  card_number INT UNIQUE NOT NULL,
  assigned_to TEXT,
  value NUMERIC NOT NULL CHECK (value IN (10, 20)),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE cards_presidenti ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "cards_presidenti_presidente" ON cards_presidenti;
DROP POLICY IF EXISTS "cards_presidenti_admin" ON cards_presidenti;
CREATE POLICY "cards_presidenti_presidente" ON cards_presidenti FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'presidente'));
CREATE POLICY "cards_presidenti_admin" ON cards_presidenti FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- =============================================
-- 3. FUNCTIONS ADMIN - GESTIONE UTENTI
-- =============================================

-- Lista utenti con profili
CREATE OR REPLACE FUNCTION admin_list_users()
RETURNS TABLE (
  out_id UUID,
  out_email TEXT,
  out_role TEXT,
  out_created_at TIMESTAMPTZ
) AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin') THEN
    RAISE EXCEPTION 'Non autorizzato';
  END IF;

  RETURN QUERY
  SELECT
    u.id AS out_id,
    u.email::TEXT AS out_email,
    p.role AS out_role,
    u.created_at AS out_created_at
  FROM auth.users u
  JOIN profiles p ON u.id = p.id
  ORDER BY u.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Crea utente
CREATE OR REPLACE FUNCTION admin_create_user(
  user_email TEXT,
  user_password TEXT,
  user_role TEXT DEFAULT 'membro'
)
RETURNS UUID AS $$
DECLARE
  new_user_id UUID;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin') THEN
    RAISE EXCEPTION 'Non autorizzato';
  END IF;

  new_user_id := gen_random_uuid();
  INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at)
  VALUES (
    new_user_id,
    user_email,
    crypt(user_password, gen_salt('bf')),
    NOW()
  );

  UPDATE profiles SET role = user_role WHERE profiles.id = new_user_id;

  RETURN new_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Modifica utente (email e ruolo)
CREATE OR REPLACE FUNCTION admin_update_user(
  target_user_id UUID,
  new_email TEXT,
  new_role TEXT
)
RETURNS VOID AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin') THEN
    RAISE EXCEPTION 'Non autorizzato';
  END IF;

  UPDATE auth.users SET email = new_email WHERE auth.users.id = target_user_id;
  UPDATE profiles SET role = new_role WHERE profiles.id = target_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Reset password
CREATE OR REPLACE FUNCTION admin_reset_password(
  target_user_id UUID,
  new_password TEXT
)
RETURNS VOID AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin') THEN
    RAISE EXCEPTION 'Non autorizzato';
  END IF;

  UPDATE auth.users
  SET encrypted_password = crypt(new_password, gen_salt('bf'))
  WHERE auth.users.id = target_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Elimina utente
CREATE OR REPLACE FUNCTION admin_delete_user(target_user_id UUID)
RETURNS VOID AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin') THEN
    RAISE EXCEPTION 'Non autorizzato';
  END IF;

  DELETE FROM profiles WHERE profiles.id = target_user_id;
  DELETE FROM auth.users WHERE auth.users.id = target_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- 4. RLS CARDS ESISTENTE - aggiornamento per ruoli
-- =============================================
-- La tabella cards esistente resta accessibile a tutti gli autenticati
-- (non cambia nulla per la sezione "Schede" originale)
