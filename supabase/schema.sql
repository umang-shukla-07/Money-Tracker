-- ==============================================================================
-- LedgerLens Supabase Database Schema
-- Multi-user local-first synchronization with Row-Level Security (RLS)
-- ==============================================================================

-- 1. CATEGORIES TABLE
CREATE TABLE IF NOT EXISTS categories (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    icon TEXT NOT NULL,
    color TEXT NOT NULL,
    is_system BOOLEAN NOT NULL DEFAULT false,
    description TEXT,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 2. MERCHANT RULES TABLE (Heuristic engine overrides)
CREATE TABLE IF NOT EXISTS merchant_rules (
    id TEXT PRIMARY KEY,
    pattern TEXT NOT NULL,
    merchant_name TEXT NOT NULL,
    category_name TEXT NOT NULL,
    is_regex BOOLEAN NOT NULL DEFAULT false,
    priority INTEGER NOT NULL DEFAULT 0,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 3. TRANSACTIONS TABLE
CREATE TABLE IF NOT EXISTS transactions (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    date TEXT NOT NULL,
    amount BIGINT NOT NULL, -- Stored as integer paise (₹1.00 = 100 paise)
    direction TEXT NOT NULL CHECK (direction IN ('credit', 'debit')),
    raw_description TEXT NOT NULL,
    clean_merchant_name TEXT NOT NULL,
    category_name TEXT NOT NULL,
    category_id TEXT REFERENCES categories(id) ON DELETE SET NULL,
    confidence DOUBLE PRECISION NOT NULL DEFAULT 1.0,
    review_status TEXT NOT NULL DEFAULT 'confirmed' CHECK (review_status IN ('confirmed', 'needs_review', 'flagged')),
    hash TEXT NOT NULL,
    balance BIGINT,
    bank_format TEXT,
    notes TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    deleted BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 4. PERFORMANCE & SYNC INDEXES
CREATE INDEX IF NOT EXISTS idx_transactions_user_updated 
    ON transactions(user_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_transactions_user_hash 
    ON transactions(user_id, hash);

CREATE INDEX IF NOT EXISTS idx_transactions_user_date 
    ON transactions(user_id, date DESC);

-- 5. ROW LEVEL SECURITY (RLS) CONFIGURATION
-- Strict data isolation: each sibling can only read and mutate their own records

ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE merchant_rules ENABLE ROW LEVEL SECURITY;

-- Transactions Policies
DROP POLICY IF EXISTS "User transactions isolation" ON transactions;
CREATE POLICY "User transactions isolation"
    ON transactions
    FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Categories Policies (System defaults readable by all authenticated users, custom scoped to user)
DROP POLICY IF EXISTS "Read categories policy" ON categories;
CREATE POLICY "Read categories policy"
    ON categories
    FOR SELECT
    TO authenticated
    USING (user_id IS NULL OR auth.uid() = user_id);

DROP POLICY IF EXISTS "Manage user categories" ON categories;
CREATE POLICY "Manage user categories"
    ON categories
    FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Merchant Rules Policies
DROP POLICY IF EXISTS "Read merchant rules policy" ON merchant_rules;
CREATE POLICY "Read merchant rules policy"
    ON merchant_rules
    FOR SELECT
    TO authenticated
    USING (user_id IS NULL OR auth.uid() = user_id);

DROP POLICY IF EXISTS "Manage user merchant rules" ON merchant_rules;
CREATE POLICY "Manage user merchant rules"
    ON merchant_rules
    FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 6. SYSTEM DEFAULT CATEGORIES SEED DATA
INSERT INTO categories (id, name, icon, color, is_system, description)
VALUES
    ('cat_food', 'Food & Dining', 'restaurant', '#FF6B6B', true, 'Restaurants, cafes, food delivery (Swiggy, Zomato)'),
    ('cat_groceries', 'Groceries', 'shopping_basket', '#4ECDC4', true, 'Supermarkets, quick-commerce (Blinkit, Instamart, Zepto)'),
    ('cat_shopping', 'Shopping', 'shopping_bag', '#FFE66D', true, 'Ecommerce (Amazon, Flipkart, Myntra) & retail stores'),
    ('cat_transport', 'Transportation', 'directions_car', '#1A535C', true, 'Ride-hailing (Uber, Ola, Rapido), metro, fuel'),
    ('cat_bills', 'Bills & Utilities', 'receipt_long', '#F7FFF7', true, 'Electricity, broadband, mobile recharges, rent'),
    ('cat_investments', 'Investments & SIP', 'trending_up', '#70C1B3', true, 'Mutual fund SIPs (Zerodha, Groww), stocks, PPF'),
    ('cat_entertainment', 'Entertainment', 'movie', '#247BA0', true, 'OTT subscriptions (Netflix, Spotify, Prime), movies'),
    ('cat_travel', 'Travel', 'flight', '#E0A96D', true, 'Flights, trains (IRCTC), hotels, vacations'),
    ('cat_salary', 'Salary & Income', 'account_balance_wallet', '#00F0FF', true, 'Monthly payroll, freelance earnings, interest credits'),
    ('cat_other', 'Other', 'more_horiz', '#A0AEC0', true, 'Unclassified and miscellaneous transactions')
ON CONFLICT (id) DO NOTHING;

