-- ============================================================
-- HANDYMAN 車両傷管理システム セットアップSQL
-- Supabase SQL Editor に貼り付けて「Run」を押してください
-- ============================================================

-- ① vehicle_twins（既存 vehicles テーブルと連動）
CREATE TABLE IF NOT EXISTS vehicle_twins (
  id               TEXT PRIMARY KEY,        -- vehicles.code と同値 (例: 'VEL', 'ALF')
  vehicle_db_id    INTEGER,                 -- vehicles.id
  store            TEXT NOT NULL DEFAULT 'naha',
  status           TEXT NOT NULL DEFAULT 'ready',
    -- ready       : 空車
    -- out         : 貸出中
    -- returning   : 返却待ち
    -- maintenance : 整備中
  current_resv_no  TEXT,
  current_customer TEXT,
  current_damages  JSONB NOT NULL DEFAULT '[]',
  odometer         INTEGER DEFAULT 0,
  rental_count     INTEGER DEFAULT 0,
  last_event_id    UUID,
  last_check_at    TIMESTAMPTZ,
  last_check_staff TEXT,
  locked_by        TEXT,                    -- 対応中スタッフ名
  locked_at        TIMESTAMPTZ,             -- ロック取得時刻（30分で自動解除）
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);

-- ② check_events（追記のみ・傷チェーン）
CREATE TABLE IF NOT EXISTS check_events (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id       TEXT NOT NULL,           -- vehicle_twins.id
  event_type       TEXT NOT NULL,
    -- 'checkout'  : 出庫チェック
    -- 'return'    : 返却チェック
    -- 'repair'    : 修理完了
    -- 'initial'   : 初期登録
  resv_no          TEXT,
  customer_name    TEXT,
  staff            TEXT NOT NULL,
  damages_snapshot JSONB NOT NULL DEFAULT '[]',
  new_damages      JSONB NOT NULL DEFAULT '[]',
  video_url        TEXT,
  ai_confidence    NUMERIC(5,2),
  staff_confirmed  BOOLEAN DEFAULT FALSE,
  confirmed_at     TIMESTAMPTZ,
  notes            TEXT,
  prev_event_id    UUID,
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- ③ 既存 vehicles テーブルから vehicle_twins を自動生成
INSERT INTO vehicle_twins (id, vehicle_db_id, store, status)
SELECT code, id, 'naha', 'ready'
FROM vehicles
WHERE active = true
ON CONFLICT (id) DO NOTHING;

-- ④ インデックス
CREATE INDEX IF NOT EXISTS idx_ce_vehicle  ON check_events(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_ce_created  ON check_events(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_vt_store    ON vehicle_twins(store);
CREATE INDEX IF NOT EXISTS idx_vt_status   ON vehicle_twins(status);

-- ⑤ RLS（読み書き許可）
ALTER TABLE vehicle_twins  ENABLE ROW LEVEL SECURITY;
ALTER TABLE check_events   ENABLE ROW LEVEL SECURITY;

CREATE POLICY "vt_all"  ON vehicle_twins  FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "ce_all"  ON check_events   FOR ALL USING (true) WITH CHECK (true);

-- ⑥ 確認クエリ（実行後にこれで確認）
SELECT v.code, v.name, v.plate_no, vt.status, vt.current_damages
FROM vehicles v
JOIN vehicle_twins vt ON v.code = vt.id
WHERE v.active = true
ORDER BY v.code;
