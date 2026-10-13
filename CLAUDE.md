# 車両損傷チェックAPP（handyman-damage）— 入口
- ルール＝`~/.claude/CLAUDE.md`（核・自動読込）。構成・デプロイ・データ構造＝スキル `handyman-damage-app`。経緯は `~/.claude/knowledge/spk.md`（旧 CLAUDE.md 全文も退避済み）。
- 本番 https://nosh2318.github.io/handyman-damage/ ／リポ nosh2318/handyman-damage（GitHub Pages）。
- DB：main `ckrxttbnawkclshczsia` の `vehicle_twins`＋`check_events`（高松は BT 側に同名表）。車両解決は `vehicle_code`＝`vehicle_twins.id` の完全一致（ナンバー部分一致は禁止）。
