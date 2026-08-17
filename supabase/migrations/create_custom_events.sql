-- =============================================
-- SCHEMA COMPLETO - Gestionale Sede
-- (RIFERIMENTO - NON ESEGUIRE DA QUI)
-- Per aggiungere custom_events, esegui solo
-- la sezione 7 nello SQL Editor di Supabase
-- =============================================

-- =============================================
-- DROP COMPLETO
-- =============================================
DROP POLICY IF EXISTS "Allow all for authenticated" ON treasury_balance;
DROP POLICY IF EXISTS "Allow all for authenticated" ON treasury_movements;
DROP TABLE IF EXISTS member_payments CASCADE;
DROP TABLE IF EXISTS member_notes CASCADE;
DROP TABLE IF EXISTS members CASCADE;
DROP TABLE IF EXISTS custom_events CASCADE;
DROP TABLE IF EXISTS treasury_balance CASCADE;
DROP TABLE IF EXISTS treasury_movements CASCADE;
DROP TABLE IF EXISTS inventory CASCADE;
DROP TABLE IF EXISTS quota_config CASCADE;

-- =============================================
-- 1. INVENTARIO
-- =============================================
CREATE TABLE inventory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_name TEXT NOT NULL,
  quantity INT NOT NULL DEFAULT 0,
  min_threshold INT NOT NULL DEFAULT 5,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE inventory ENABLE ROW LEVEL SECURITY;
CREATE POLICY "inventory_all" ON inventory FOR ALL USING (true);

-- =============================================
-- 2. TESORERIA
-- =============================================
CREATE TABLE treasury_balance (
  id INT PRIMARY KEY DEFAULT 1,
  balance NUMERIC(12, 2) NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT single_row CHECK (id = 1)
);

INSERT INTO treasury_balance (id, balance) VALUES (1, 0)
ON CONFLICT (id) DO NOTHING;

CREATE TABLE treasury_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL CHECK (type IN ('entrata', 'uscita', 'correzione')),
  amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
  description TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_movements_created ON treasury_movements (created_at DESC);

ALTER TABLE treasury_balance ENABLE ROW LEVEL SECURITY;
ALTER TABLE treasury_movements ENABLE ROW LEVEL SECURITY;
CREATE POLICY "treasury_balance_all" ON treasury_balance FOR ALL USING (true);
CREATE POLICY "treasury_movements_all" ON treasury_movements FOR ALL USING (true);

-- =============================================
-- 3. SOCI
-- =============================================
CREATE TABLE members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nome TEXT NOT NULL,
  cognome TEXT NOT NULL,
  roadname TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================
-- 4. NOTE SOCI
-- =============================================
CREATE TABLE member_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id UUID REFERENCES members(id) ON DELETE CASCADE,
  note_text TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================
-- 5. PAGAMENTI MENSILI
-- =============================================
CREATE TABLE member_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id UUID REFERENCES members(id) ON DELETE CASCADE,
  month INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12),
  year INTEGER NOT NULL,
  paid BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(member_id, month, year)
);

-- =============================================
-- 6. CONFIG QUOTA (singleton)
-- =============================================
CREATE TABLE quota_config (
  id INTEGER PRIMARY KEY DEFAULT 1,
  amount NUMERIC DEFAULT 70,
  updated_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO quota_config (id, amount) VALUES (1, 70);

-- =============================================
-- RLS SOCI + NOTE + PAGAMENTI
-- =============================================
ALTER TABLE members ENABLE ROW LEVEL SECURITY;
ALTER TABLE member_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE member_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE quota_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "members_all" ON members FOR ALL USING (true);
CREATE POLICY "member_notes_all" ON member_notes FOR ALL USING (true);
CREATE POLICY "member_payments_all" ON member_payments FOR ALL USING (true);
CREATE POLICY "quota_config_all" ON quota_config FOR ALL USING (true);

-- =============================================
-- 7. EVENTI PERSONALIZZATI
-- =============================================
CREATE TABLE IF NOT EXISTS custom_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_name TEXT NOT NULL,
  schema_definition TEXT NOT NULL DEFAULT '[]',
  rows_data TEXT NOT NULL DEFAULT '[]',
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE custom_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "custom_events_all" ON custom_events FOR ALL USING (true);
