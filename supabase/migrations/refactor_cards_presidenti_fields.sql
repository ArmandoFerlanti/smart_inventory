-- =============================================
-- REFACTOR TABELLA CARDS PRESIDENTI
-- card_number (INT)  -> assigned_to (TEXT)   "Assegnata a"
-- assigned_to (TEXT) -> released_on (DATE)   "Rilasciata il"
-- value (NUMERIC)    -> expires_on (DATE)    "Scadenza"
-- =============================================

-- 1. Rinomina colonne (ordine studiato per liberare i nomi)
ALTER TABLE cards_presidenti RENAME COLUMN assigned_to TO released_on;
ALTER TABLE cards_presidenti RENAME COLUMN value TO expires_on;
ALTER TABLE cards_presidenti RENAME COLUMN card_number TO assigned_to;

-- 2. Rimozione vincoli obsoleti
ALTER TABLE cards_presidenti ALTER COLUMN assigned_to DROP DEFAULT;
ALTER TABLE cards_presidenti DROP CONSTRAINT IF EXISTS cards_presidenti_card_number_key;
ALTER TABLE cards_presidenti DROP CONSTRAINT IF EXISTS cards_presidenti_value_check;

-- 3. Conversione tipi
-- INT -> TEXT: il numero scheda diventa il nome della persona
ALTER TABLE cards_presidenti ALTER COLUMN assigned_to TYPE TEXT USING assigned_to::TEXT;
ALTER TABLE cards_presidenti ALTER COLUMN assigned_to SET NOT NULL;

-- TEXT/NUMERIC -> DATE: i vecchi valori non sono date, vengono azzerati
ALTER TABLE cards_presidenti ALTER COLUMN released_on TYPE DATE USING NULL::DATE;
ALTER TABLE cards_presidenti ALTER COLUMN expires_on TYPE DATE USING NULL::DATE;
