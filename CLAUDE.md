# 車両損傷チェックAPP（handyman-damage）

## 概要
- **URL**: https://nosh2318.github.io/handyman-damage/
- **リポジトリ**: nosh2318/handyman-damage（GitHub Pages 自動デプロイ）
- **構成**: 単一 index.html（約3800行・素のJS）+ sw.js + v.html(お客様向け公開ビュー) + manifest.json + schema.sql/setup.sql
- **DB**: Supabase `ckrxttbnawkclshczsia`（NHA/SPK共通）の `vehicle_twins` + `check_events`
- **店舗切替**: naha / sapporo（currentStore）
- **現在バージョン**: v2.7.5-DAMAGE / sw.js CACHE=handyman-damage-v14

## デプロイ手順
1. index.html / sw.js を編集
2. `index.html` の version文字列2箇所（sm-logo `vX.X.X` + `APP_VERSION='vX.X.X-DAMAGE'`）と `sw.js` の `CACHE` を同時バンプ
3. `git add … && git commit && git push origin main`（pre-push で node --check 自動実行）

## データ構造の要点（重要）
- **naha の車両ソースは `nha_vehicles`**（2026-05-11 に nha_cars から切替）。`nha_vehicles.code` が車両ID。
- **vehicle_twins.id = nha_vehicles.code**（naha）。`vehicle_db_id` にも code が入る。twin行が無い車両＝**未初期登録**（チェーン起点なし）。
- check_events.vehicle_id は schema.sql 上は vehicle_twins(id) への FK 宣言だが、**本番DBではFK未適用**（twin無しでもINSERT通る）。
- nha_vehicles.code の命名 = 車種略号+連番（例 VTZ02 ヴィッツ② / ALF09 アルファード⑨ / PRI06 プリウス⑥ / AQA02 アクア② / VOX03 ヴォクシー③）。
  - ⚠️ スタッフは旧命名（車種略号+ナンバー、例 VIT51/ALH7401/PLU5348/AQA416/ViT8/VOX490）で呼ぶことがある。報告コードが nha_vehicles に無い時は「車種＋ナンバー下数桁」で対応付ける。

## 🔴 2026-06-04 初期登録の保存ボタンが押せなくなる固着バグ 修正（v2.7.5 / cache v14）
### 症状
那覇店の傷チェックで、未初期登録の6台（VIT51/AQA416/PLU5348/ViT8/ALH7401/VOX490 ＝現行 VTZ02/AQA02/PRI06/VTZ03/ALF09/VOX03）が
「傷の登録ができず・保存ボタンが押せない」。いずれも `vehicle_twins` 行なし＝**初期登録（チェーン起点作成）から保存する車両**。
### 真因
`openSi()`（初期登録/編集のSI画面を開く処理・index.html ~L3203）が保存ボタン `siCompleteBtn` の **textContent だけ戻し、`style.pointerEvents` をリセットしていなかった**。
保存(`siComplete`)は開始時に `btn.style.pointerEvents='none'` を立てるが、**前回の保存が中断（通信ハング／30秒watchdog発火前に画面を戻す等）すると none が inline style として残存**。
SI画面は静的DOMで再生成されないため、開き直しても「✓登録完了」表示のまま**押下不能で固着**。リロード（🔄最新版ボタン＝forceAppUpdate）でしか直らなかった。
### 修正
`openSi()` の末尾で SI画面を開くたびに `siCompleteBtn.style.pointerEvents='all'` を必ず復帰（index.html ~L3221）。再発しない。
### 現場対応
固着中の端末は上部の **🔄 最新版** ボタンで1回更新すれば直る。更新後、各車「初期登録」から登録する。
### Lesson（再発防止）
- **inline で `pointerEvents='none'`（や disabled）を立てる保存ボタンは、画面を開く処理で必ず復帰させる**。catch/watchdog だけでは「途中で戻る」をカバーできず固着する。
- 同型リスク: `submitEdit` の `_submitEditBusy` フラグ、貸出(s-checkout)・返却(sr0)の submitBtn も「open時リセット」が無いと同じ固着が起き得る → 次に触る時に open側リセットを足す。
- 単一HTML/SPAでボタンが静的DOMの場合、inline style は画面遷移で消えない＝セッション中ずっと残る点に注意。

## 過去の主な修正
- 2026-05-29: 保存系すべてに30秒タイムアウト watchdog 追加＋写真480px/quality0.4圧縮（保存フリーズ対策）。check_events は傷メタのみ・写真は vehicle_twins.current_damages に保存しペイロード削減。
- 2026-05-26: お客様向け共有URL（v.html・share_token/share_enabled・anon RLS）。
- 2026-05-11: naha車両ソースを nha_cars → nha_vehicles に切替。
- グローバルエラーハンドラ（window.onerror 赤バナー）＋ pre-push の node --check で白画面/構文事故を防止。
