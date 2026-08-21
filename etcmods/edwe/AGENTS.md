# AGENTS.md — edwe (EdWorldEdit)

Мод-аналог WorldEdit для Luanti 5.14.0+ (работает и на Minetest Game, и на VoxeLibre/MCL).
Два инструмента:
- **Fill Axe** `edwe:wooden_axe` — отмечает две позиции, третий ПКМ → заполняет кубоид выбранным блоком.
- **Delete Axe** `edwe:wooden_axe_delete` — (перевёрнутая текстура) отмечает две позиции, третий ПКМ → удаляет всё в кубоиде (ставит air).
Общая механика: ЛКМ → pos1, ПКМ → pos2, ПКМ → действие. Работает и в креативе, и в survival.

## Полное ТЗ

### Инструменты

- `edwe:wooden_axe` — Fill Axe, **не копает блоки** (нет `tool_capabilities`).
  Текстура: `textures/edwe_wooden_axe.png` (копия деревянного топора VoxeLibre). Крафт: 3 wood + 2 stick + Creative.
- `edwe:wooden_axe_delete` — Delete Axe, тоже не копает.
  Текстура: `textures/edwe_wooden_axe_delete.png` (та же текстура, повёрнута на 180°). Крафт: тот же рецепт + Creative.

### Механика отметок (конечный автомат, состояние per-player)

`edwe.player[name]` (Fill) и `edwe.player_del[name]` (Delete) — раздельные таблицы, формат `{ pos1 = vector, pos2 = vector }`.
Фаза выводится из полей: нет `pos1` → фаза 0; есть `pos1`, нет `pos2` → фаза 1; есть оба → фаза 2 (готово к действию).

**Правило выбора позиции по клику:** позиция всегда берётся из `pointed_thing.above` —
это координата, прилегающая к указанной грани блока. Клик по верхней грани → позиция
над блоком (`above`). Клик по боковой грани → позиция сбоку от блока (`above`).
Это позволяет естественно очерчивать полы, стены и потолки. Пример: клик по верху
пола + клик по боку стены → заливка создаст слой пола до стены.

| # | Событие | Условие | Результат | Сообщение в чат (ДОСЛОВНО) |
|---|---------|---------|-----------|------------------------------|
| 1 | ЛКМ по блоку | pos1 не задан | `pos1 = блок`, фаза 1 | `EdWorldEdit :  first point set.` (ДВА пробела после `:`) |
| 2 | ЛКМ по блоку | pos1 задан | pos1 переотмечается | `EdWorldEdit :  first point set.` |
| 3 | ПКМ по блоку | pos1 не задан | игнор, ничего не происходит | — |
| 4a | ПКМ (Fill) | pos1 задан, pos2 не задан | `pos2 = блок`, фаза 2 | `EdWorldEdit: second point set. Choose item to copy.` (БЕЗ пробела после `:`) |
| 4b | ПКМ (Delete) | pos1 задан, pos2 не задан | `pos2 = блок`, фаза 2 | `EdWorldEdit: second point set. Delete region.` |
| 5a | ПКМ (Fill) | pos1 и pos2 заданы | **заливка** блоком под кликом, затем сброс | `EdWorldEdit : copy done` |
| 5b | ПКМ (Delete) | pos1 и pos2 заданы | **удаление** всего в кубоиде (→ air), затем сброс | `EdWorldEdit : delete done` |
| 6 | смена предмета в руке | состояние активно | сброс состояния | `EdWorldEdit : cancel` |

**ВНИМАНИЕ:** строки сообщений скопированы дословно из ТЗ заказчика, включая
непоследовательные пробелы. Не «исправлять» их. Отказ при слишком большом регионе:
`EdWorldEdit : region too big (<N> nodes, max <M>)` — состояние при этом СОХРАНЯЕТСЯ,
`copy done` не шлётся.

### Заливка (событие 5)

- Кубоид между `pos1` и `pos2`, включая обе позиции (границы = min/max по каждой оси).
- Блок заливки — нода, на которую пришёлся третий ПКМ-клик (не предмет в руке).
- Правило пропуска:

| Нода в кубоиде | Действие |
|---|---|
| `air` | заполняется |
| вода (имя содержит `water`: `default:water_*`, `mcl_core:water_*`, `mcl_core:river_water_*`) | **затирается** блоком заливки |
| трава (имя содержит `grass`: `default:grass_1..5`, `default:dirt_with_grass*`, `mcl_core:grass_block`, `mcl_core:short_grass`) | **затирается** блоком заливки |
| любой другой занятый блок | **пропускается** (остаётся) |
| `ignore` (незагруженный чанк) | пропускается |
| защищённая нода (`minetest.is_protected`) | пропускается |

- Заливка: creative — бесплатно; survival — расход блоков из инвентаря; fill=air — всегда бесплатно.
- `param2` исходной ноды копируется через `bulk_set_node(list, fill)` (fill = таблица ноды от `get_node`).
- Лимит: `edwe.max_nodes` (settingtypes.txt, по умолчанию 10000).

### Удаление (событие 5b, Delete Axe)

- Кубоид между `pos1` и `pos2`, включая обе позиции.
- Правило: ВСЁ → `air`, кроме `air`, `ignore` и protected-нод.
- Всегда бесплатно (creative и survival), блоки НЕ возвращаются в инвентарь.
- `bulk_set_node(list, {name = "air"})` — единый вызов для всех позиций.

## Архитектура (shared helpers, без копипасты)

Оба инструмента используют общие хелперы в `init.lua`:
- `edwe_mark_first(itemstack, user, pt, state_tab)` — ЛКМ: отметка pos1.
- `edwe_mark_second_or_act(itemstack, user, pt, state_tab, action_fn, msg2)` — ПКМ: pos2 или вызов action_fn.
- `edwe_action_fill(name, pos1, pos2, pt)` — fill-action: get_node(pt.under) + edwe_fill_cuboid.
- `edwe_action_delete(name, pos1, pos2, pt)` — delete-action: edwe_delete_cuboid.
- `edwe_check_tool(name, state_tab, tool_name)` — проверка смены инструмента в globalstep.

Регистрация инструментов — тонкие обёртки (2 строки на хендлер), без дублирования логики.

## Структура мода

```
edwe/
  mod.conf            -- name = edwe (БЕЗ depends; совместимость через group:wood/group:stick и паттерны имён)
  init.lua            -- edwe={}; state tables; shared helpers; action functions; tool registration; crafts; globalstep; leaveplayer
  fill.lua            -- edwe_is_water(); edwe_is_grass(); edwe_fill_cuboid(); edwe_delete_cuboid()
  settingtypes.txt    -- edwe.max_nodes
  textures/edwe_wooden_axe.png
  textures/edwe_wooden_axe_delete.png
  license.txt         -- MIT
  README.md
```

## Правила разработки

### Стиль кода: комментировать каждый закрывающий блок

Каждый `end`, `elseif`, `else` — с хвостовым комментарием, что он закрывает:
`-- if <условие>` / `-- loop over <что>` / `-- while <условие>` / `-- function <имя>`.
Вложенные циклы — отдельные комментарии на каждый.

### Стиль кода: никогда не коммитить некомпилируемый код

После каждого изменения проверять синтаксис (из корня репозитория vbots2, где лежит luac54.exe):

```bash
.\luac\luac54.exe -p init.lua
.\luac\luac54.exe -p fill.lua
```

Обе команды должны давать код 0 (нет вывода = ок). `luac -p` ловит только синтаксис —
рантайм проверять в игре/на headless-сервере.

### Стиль кода: централизация и глобальные функции

- Кросс-файловые функции/переменные (`edwe`, `edwe.player`, `edwe.player_del`,
  `edwe_is_water`, `edwe_is_grass`, `edwe_fill_cuboid`, `edwe_delete_cuboid`,
  `edwe_mark_first`, `edwe_mark_second_or_act`) — ТОЛЬКО глобальные (без `local`).
- Обработчики-обёртки (`edwe_lmb_fill`, `edwe_rmb_fill`, `edwe_lmb_del`, `edwe_rmb_del`) — тоже глобальные.
- `edwe.max_nodes` выставляется в init.lua сразу после `edwe = {}`.

## Нюансы движка (проверено)

- **В Luanti НЕТ** колбэка «игрок сменил предмет в руке» (`register_on_player_change_item`
  не существует — подтверждено поиском по GitHub и документации). Детект смены — через
  `register_globalstep`-опрос `player:get_wielded_item():get_name()` ТОЛЬКО для игроков
  с активным состоянием (обычно 0–1, оверхед минимален).
- Наличие `on_use` у `register_tool` отключает дефолтное копание по ЛКМ.
- Наличие `on_place` перехватывает ПКМ: `on_rightclick` ноды-контейнера (сундук, печь)
  НЕ вызывается — топорик не открывает контейнеры.
- Оба обработчика проверяют `pointed_thing.type == "node"`; клик по воздуху (`"nothing"`)
  или объекту (`"object"`) — no-op.
- `bulk_set_node` принимает единую таблицу ноды `{name=…, param2=…}` для всех позиций.
- ПКМ до ЛКМ — игнор (событие 3), без сообщений.
- pos1 == pos2 — заливается 1 нода.
- Залить водой тоже валидно (клик третьим по воде/воде) — «залить водой».

## Тест-чеклист (после изменений)

- [ ] ЛКМ по блоку → `EdWorldEdit :  first point set.`
- [ ] ПКМ по блоку → `EdWorldEdit: second point set. Choose item to copy.`
- [ ] ПКМ по третьему блоку → кубоид заполнен, `EdWorldEdit : copy done`, состояние сброшено
- [ ] Занятые блоки (камень) в кубоиде остались; воздух заполнен
- [ ] Вода и трава в кубоиде затёрты блоком заливки
- [ ] Смена предмета в руке после 1-й/2-й отметки → `EdWorldEdit : cancel`, отметки сброшены
- [ ] ПКМ до ЛКМ — ничего не происходит
- [ ] ЛКМ/ПКМ по существу или воздуху — ничего не происходит
- [ ] Топорик не копает блоки, не открывает сундуки/печи
- [ ] Fill + Delete: работают и в креативе, и в survival
- [ ] Fill + Delete: защищённая территория не трогается
- [ ] Fill + Delete: регион больше `edwe.max_nodes` → отказ с сообщением, состояние сохраняется
- [ ] Fill + Delete: выход игрока с активным состоянием → состояние очищается
- [ ] Delete Axe: ПКМ по второму блоку → `EdWorldEdit: second point set. Delete region.`
- [ ] Delete Axe: третий ПКМ → кубоид очищен (всё → air), `EdWorldEdit : delete done`, состояние сброшено
- [ ] Delete Axe: air и ignore в кубоиде не трогаются (не отправляются в bulk_set_node)
- [ ] Delete Axe: смена с Delete Axe на Fill Axe → cancel для delete-состояния (раздельные таблицы)
- [ ] Оба инструмента: одновременное использование (Fill pos1 + Delete pos1) не конфликтуют (раздельные `edwe.player` / `edwe.player_del`)

## Проверка в игре (headless)

Мод НЕ включён в `world.mt` мира `worlds/2` (по решению владельца — включать вручную).
Проверка загрузки: добавить `load_mod_edwe = mods/edwe` в
`L:\games\luanti-5.14.0-win64\worlds\2\world.mt`, запустить
`bin\luanti.exe --server --world worlds/2` (= runserver.bat), ошибки искать в
`L:\games\luanti-5.14.0-win64\debug.txt` (первый `ServerError`/`ModError`).