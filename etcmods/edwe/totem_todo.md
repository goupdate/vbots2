# Protection Totem (edwe:protect_totem) — План работ

## ТЗ

- Блок `edwe:protect_totem` — золотой, размещаемый на земле
- Зона: столб ±20 по X/Z (41×41), вся высота
- Лимит: ≤10 тотемов на игрока
- Защита: копание и стройка запрещены всем кроме владельца — `minetest.register_protection_handler`
- Entity-табличка над тотемом: `playerX : totem N`, золотой цвет, неизменяемый текст
- Снос: только владелец (`can_dig`)
- Персист: LBM восстанавливает индекс при загрузке чанка

## Боты и защита

`register_protection_handler(pos, name)` получает `name` (имя игрока). Боты работают от имени владельца (`vbots2.bot_info[key].owner`). Нужно добавить проверку `minetest.is_protected(pos, owner)` в `bot_parsecommand` и `move_bot` перед копанием/размещением — тогда боты тоже не смогут ломать/строить в чужих зонах.

## Архитектура

```
protect.lua:
├─ edwe._totems = {}  — индекс in-memory: {["player"] = {count=N, zones=[{x,z,n}], by_pos={[hash]=true}}}
│
├─ edwe:protect_totem node:
│  ├─ tiles = edwe_totem_block.png (золотой, 16×16)
│  ├─ on_place → проверить ≤10, записать meta (owner, totem_N), register зону, спавн label entity
│  ├─ can_dig → только meta:get_string("owner") == digger
│  └─ after_dig_node → unregister зону, удалить label entity
│
├─ edwe:totem_label entity:
│  ├─ upright_sprite, texture = edwe_totem_tablet.png (золотая табличка 16×32)
│  ├─ visual_size = {x=0.5, y=1.0}
│  ├─ nametag = "owner : totem N", nametag_color = "#FFD700" (золотой)
│  └─ позиция: totem_pos + (0.5, 1.2, 0.5)
│
├─ edwe.register_totem(player_name, pos, n) — обновление индекса
├─ edwe.unregister_totem(player_name, pos) — удаление из индекса
│
├─ minetest.register_protection_handler:
│  └─ для pos: перебор всех зон (abs(dx) ≤ 20 && abs(dz) ≤ 20), owner пропускается, остальные → true
│
└─ minetest.register_lbm { name="edwe:register_totems", nodenames={"edwe:protect_totem"},
     run_at_every_load=true, action = rebuild index }

init.lua: + dofile("protect.lua")
```

## Файлы

| # | Файл | Что |
|---|------|-----|
| 1 | init.lua | `dofile("protect.lua")` |
| 2 | protect.lua | нода + entity + индекс + protection_handler + LBM |
| 3 | textures/edwe_totem_block.png | золотой блок 16×16 |
| 4 | textures/edwe_totem_tablet.png | золотая табличка 16×32 |

## Задачи

| # | Задача |
|---|---|
| 1 | protect.lua: register_node edwe:protect_totem (on_place, can_dig, after_dig_node) |
| 2 | protect.lua: register_entity edwe:totem_label (upright_sprite, nametag золотой) |
| 3 | protect.lua: edwe._totems индекс + register/unregister_totem |
| 4 | protect.lua: minetest.register_protection_handler (zone check) |
| 5 | protect.lua: LBM восстановление индекса при загрузке |
| 6 | textures: edwe_totem_block.png + edwe_totem_tablet.png |
| 7 | init.lua: dofile("protect.lua") |
| 8 | Интеграция: проверка is_protected в ботов |
| 9 | luac54 -p + README + AGENTS.md |