# План: программы ботов в mod_storage (detached inventory) — «указатель» по bot_key

## Цель

Убрать 392 слота программ (p0..p6) из меты узла бота, чтобы `position_bot` (meta:to_table/from_table)
копировал только ~15 полей + main(32) вместо 425 слотов на каждый шаг.

## Дизайн (гибридный)

| Данные | Где живут | Почему |
|---|---|---|
| Программы p0..p6 (392 слота) | detached inventory `botprog_<bot_key>` + зеркало в `mod_storage["botprog_<bot_key>"]` | меняются только через UI (редко) — запись в storage дешёвая; переживают рестарт |
| main (32 слота) | остаётся в node meta | меняется постоянно (копка/подбор/стройка) — бесплатная персистентность через mapblock save; кросс-бот доступ (dig_build:21) без изменений |
| trash | как есть: detached `bottrash` (общий) | уже работает |

Ключ `bot_key` в мете узла = «указатель»: при движении копируется только он,
данные в глобальной карте (`mod_storage`) остаются на месте.

## Миграция

- **Сейвы (`world,vbotsep,owner,vbotsep,botname`)** — формат НЕ меняется: это сериализованный
  список `"pN itemname count"`, не зависящий от места хранения. Конвертация сейвов не нужна.
- **Живые узлы ботов** — одноразовая ленивая миграция в `bot_restore`:
  1. если в node meta есть p-листы (`inv:get_size("p0") > 0`) — прочитать p0..p6 в inv_list-формат,
     записать в `mod_storage["botprog_<key>"]`, очистить p-листы узла (`set_size(pN,0)`);
  2. создать detached `botprog_<key>` из storage (или пустой) + коллбеки.
  Покрытие: бегущие боты — первый тик (self-heal), остановленные — первый правый клик.
- **Порядок в одном коммите** обязателен: миграция + переход на detached читают данные до очистки.

## Затрагиваемые файлы (10)

| Файл | Изменения |
|---|---|
| init.lua | хелперы `vbots2.ensure_prog_inv(key)`, `vbots2.prog_inv(key)`, `vbots2.save_prog_inv(key)`; bot_init: p-листы только в detached, не в node inv; bot_restore: миграция + восстановление detached из storage; wipe_programs: очистка detached; save: чтение detached (формат сейва тот же); `register_on_shutdown`: flush всех detached в storage |
| nodes.lua | коллбеки allow/on_put/on_take для p-листов перенести из node def в detached def (сигнатура та же, логика «дубликат» без изменений); on_destruct: удалить `mod_storage["botprog_<key>"]` (программы умирают с узлом — текущая семантика); main-drop в on_destruct не трогаем |
| formspec.lua | строка 102: `list[nodemeta:pos;pN;...]` → `list[detached:botprog_<key>;pN;...]` (ключ из меты pos) |
| formspec_handler.lua | все операции с p-листами (95-100, 126, 153, 170-183, 194-231) → detached через key; main в узле не трогаем |
| timer.lua | чтения программ (67-114: `get_stack("p"..PR, PC)`) → detached по `meta:get_string("key")`; main остаётся node inv |
| commands.lua | 12 сайтов чтения p-листов (75-317) → `vbots2.prog_inv(key)`; main (278) → node inv (как сейчас) |
| dig_build.lua | свои p-листы (26, 64) → detached; свой main и чужой бот main (21-73, 103-187) → node inv (без изменений) |
| common.lua | `bot_add_items` уже работает с любым inv — без изменений |
| movement.lua | БЕЗ правок: to_table/from_table автоматически легче после миграции (main 32 + поля) |
| README.md/ru | не требуется: внутренний рефакторинг, поведение не меняется |

## Задачи (порядок исполнения, после каждой — сжатие контекста)

1. **init.lua**: хелперы detached + bot_init (без p-листов в узле) + миграция в bot_restore + save/wipe_programs через detached + shutdown-flush.
2. **nodes.lua**: коллбеки p-листов → detached; on_destruct удаляет storage-запись программ.
3. **formspec.lua + formspec_handler.lua**: грид программ → detached; handler → detached.
4. **timer.lua + commands.lua + dig_build.lua**: чтения программ → detached (main остаётся node).
5. **Проверка**: luac54 -p на всех файлах; headless-сервер (bin\luanti.exe --server --world worlds/2);
   runtime-тест: поставить бота → запрограммировать → движение → рестарт сервера → программы живы;
   save/load round-trip; drag&drop дубликат в UI; копка чужого бота; бомба (stop + remove).

## Риски

- detached не переживает рестарт → restore из mod_storage в ensure (всегда, до создания).
- ensure идемпотентен: сначала `get_detached_inventory`, создавать только если nil.
- формы открываются только после bot_restore → detached уже существует к моменту `list[detached...]`.
- Разделение inv в commands/dig_build: аккуратно развести node-inv (main) и detached (программы).