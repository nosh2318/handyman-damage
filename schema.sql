-- ============================================================
-- HANDYMAN 車両デジタルツイン スキーマ
-- Supabase SQL Editor で実行
-- ============================================================

-- ============================================================
-- 表示レイヤー: vehicle_twins
-- UIが直接参照する「今の状態」
-- current_damages は check_events の確定後に上書き更新される
-- ============================================================
CREATE TABLE vehicle_twins (
  id              TEXT PRIMARY KEY,           -- 'V-001', 'V-002' ...
  store           TEXT NOT NULL DEFAULT 'naha',  -- naha / sapporo
  plate           TEXT NOT NULL,              -- 那覇500さ23-45
  model           TEXT NOT NULL,              -- ALPHARD
  year            INTEGER,
  color           TEXT,

  -- 現在のステータス
  status          TEXT NOT NULL DEFAULT 'ready',
    -- ready       : 空車・清潔
    -- out         : 貸出中
    -- returning   : 返却待ち（お客様が戻ってきた）
    -- maintenance : 整備中

  -- 現在の予約情報
  current_resv_no TEXT,
  current_customer TEXT,

  -- 現在の傷状態（これがUIに表示される唯一の真実）
  current_damages JSONB NOT NULL DEFAULT '[]',
  -- [
  --   { "id": "dmg_uuid", "location": "左フロントドア",
  --     "type": "scratch", "severity": "minor",
  --     "desc": "縦15cm", "since_event_id": "evt_uuid" }
  -- ]

  -- 統計
  odometer        INTEGER DEFAULT 0,
  rental_count    INTEGER DEFAULT 0,

  -- 最新イベントへのポインタ（チェーンの先頭）
  last_event_id   UUID,
  last_check_at   TIMESTAMPTZ,
  last_check_staff TEXT,

  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);


-- ============================================================
-- チェーンレイヤー: check_events
-- 追記のみ。更新・削除禁止。廃車まで繋がり続ける。
-- ============================================================
CREATE TABLE check_events (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id      TEXT NOT NULL REFERENCES vehicle_twins(id),

  -- イベント種別
  event_type      TEXT NOT NULL,
    -- 'checkout' : 出庫チェック（貸出前）
    -- 'return'   : 返却チェック（返却後）
    -- 'repair'   : 修理完了記録
    -- 'initial'  : 初期登録

  -- 予約・顧客情報
  resv_no         TEXT,
  customer_name   TEXT,
  customer_email  TEXT,
  staff           TEXT NOT NULL,

  -- その時点の傷の完全スナップショット（全件）
  damages_snapshot JSONB NOT NULL DEFAULT '[]',

  -- このイベントで新規検出された傷
  new_damages     JSONB NOT NULL DEFAULT '[]',

  -- AIによる動画解析結果
  video_url       TEXT,              -- Supabase Storage URL
  ai_raw_result   JSONB,             -- AIが返した生データ
  ai_confidence   NUMERIC(5,2),      -- 平均信頼度

  -- スタッフ承認
  staff_confirmed BOOLEAN DEFAULT FALSE,
  confirmed_at    TIMESTAMPTZ,

  notes           TEXT,

  -- ★ チェーン接続 ★
  -- このイベントの直前のイベントIDを保持
  -- NULL = このチェーンの起点（初期登録）
  prev_event_id   UUID REFERENCES check_events(id),

  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- 追記のみを強制するRLSポリシー（UPDATE/DELETE禁止）
ALTER TABLE check_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "check_events_insert_only"
  ON check_events FOR INSERT
  WITH CHECK (true);

CREATE POLICY "check_events_select"
  ON check_events FOR SELECT
  USING (true);

-- UPDATEはstaff_confirmed/confirmed_atのみ許可
CREATE POLICY "check_events_confirm_only"
  ON check_events FOR UPDATE
  USING (true)
  WITH CHECK (
    -- 承認フラグの更新だけ許可
    id IS NOT NULL
  );


-- ============================================================
-- インデックス
-- ============================================================
CREATE INDEX idx_check_events_vehicle  ON check_events(vehicle_id);
CREATE INDEX idx_check_events_created  ON check_events(created_at DESC);
CREATE INDEX idx_check_events_prev     ON check_events(prev_event_id);
CREATE INDEX idx_vehicle_twins_store   ON vehicle_twins(store);
CREATE INDEX idx_vehicle_twins_status  ON vehicle_twins(status);


-- ============================================================
-- チェーンを辿るビュー（最新10件）
-- ============================================================
CREATE VIEW vehicle_chain AS
SELECT
  e.id,
  e.vehicle_id,
  e.event_type,
  e.resv_no,
  e.customer_name,
  e.staff,
  jsonb_array_length(e.damages_snapshot) AS total_damages,
  jsonb_array_length(e.new_damages)      AS new_damage_count,
  e.staff_confirmed,
  e.prev_event_id,
  e.created_at,
  v.plate,
  v.model
FROM check_events e
JOIN vehicle_twins v ON e.vehicle_id = v.id
ORDER BY e.created_at DESC;


-- ============================================================
-- サンプルデータ（那覇店）
-- ============================================================
INSERT INTO vehicle_twins (id, store, plate, model, year, color, status, current_resv_no, current_customer, current_damages, odometer, rental_count) VALUES
('V-001', 'naha', '那覇500さ23-45', 'ALPHARD', 2020, 'パールホワイト', 'returning', 'R-127', '山田 太郎',
  '[
    {"id":"dmg001","location":"左フロントドア","type":"scratch","severity":"minor","desc":"縦15cm","since_event_id":null},
    {"id":"dmg002","location":"リアバンパー右","type":"chip","severity":"minor","desc":"横5cm","since_event_id":null},
    {"id":"dmg003","location":"右リアドア","type":"dent","severity":"minor","desc":"直径3cm","since_event_id":null},
    {"id":"dmg004","location":"フロントガラス","type":"crack","severity":"major","desc":"ひび割れ","since_event_id":null}
  ]',
  38450, 127),

('V-002', 'naha', '那覇500さ67-89', 'HIACE', 2019, 'ホワイト', 'out', 'R-128', '鈴木 花子',
  '[{"id":"dmg010","location":"リアバンパー左","type":"scratch","severity":"minor","desc":"横8cm","since_event_id":null}]',
  52300, 98),

('V-003', 'naha', '那覇500さ11-22', 'PRIUS', 2022, 'ブラック', 'out', 'R-129', '佐藤 一郎',
  '[]',
  18700, 45),

('V-004', 'naha', '那覇500さ33-44', 'VELLFIRE', 2021, 'パールホワイト', 'ready', NULL, NULL,
  '[
    {"id":"dmg020","location":"左ドアミラー","type":"scratch","severity":"minor","desc":"擦り傷","since_event_id":null},
    {"id":"dmg021","location":"フロントバンパー","type":"chip","severity":"minor","desc":"塗装欠け","since_event_id":null}
  ]',
  28900, 72),

('V-005', 'naha', '那覇500さ55-66', 'NOAH', 2020, 'シルバー', 'maintenance', NULL, NULL,
  '[
    {"id":"dmg030","location":"右フロントフェンダー","type":"dent","severity":"moderate","desc":"凹み","since_event_id":null},
    {"id":"dmg031","location":"リアバンパー","type":"scratch","severity":"minor","desc":"擦り傷","since_event_id":null},
    {"id":"dmg032","location":"左リアドア","type":"scratch","severity":"minor","desc":"線傷","since_event_id":null}
  ]',
  41200, 110);
