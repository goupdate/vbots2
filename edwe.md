# EdWorldEdit (edwe) — Техническое задание и план работ

> Мод-аналог WorldEdit для Luanti (5.14.0+, MTG и VoxeLibre/MCL).
> Деревянный топорик отмечает две позиции (ЛКМ / ПКМ), третий ПКМ-клик по блоку
> выбирает блок-«заливку» и заполняет кубоид между отмеченными позициями.
> Работает и в креативе, и в обычной (survival) игре.

---

## 1. Требования (из ТЗ)

### 1.1. Инструмент

- Новый инструмент `edwe:wooden_axe` — деревянный топорик (текстура по мотивам деревянного топора).
- **Не копает блоки** — ЛКМ используется только для отметки позиции.
- Получение: крафт по рецепту деревянного топора (3 доски + 2 палки) и/или вкладка Creative. *(Решение 1)*

### 1.2. Механика отметок (конечный автомат)

| # | Событие | Условие | Результат | Сообщение в чат (дословно) |
|---|---------|---------|-----------|------------------------------|
| 1 | **ЛКМ** по блоку | pos1 не задан | `pos1 = блок`, фаза 1 | `EdWorldEdit :  first point set.` |
| 2 | **ЛКМ** по блоку | pos1 задан | pos1 переотмечается (новый блок) | `EdWorldEdit :  first point set.` |
| 3 | **ПКМ** по блоку | pos1 не задан | игнор (no-op), ничего не происходит | — |
| 4 | **ПКМ** по блоку | pos1 задан, pos2 не задан | `pos2 = блок`, фаза 2 | `EdWorldEdit: second point set. Choose item to copy.` |
| 5 | **ПКМ** по блоку | pos1 и pos2 заданы | **заливка** блоком, на который кликнули, затем сброс состояния | `EdWorldEdit : copy done` |
| 6 | смена предмета в руке | состояние активно | сброс состояния | `EdWorldEdit : cancel` |

> **Важно:** строки сообщений копируются дословно из ТЗ, включая непоследовательные
> пробелы: `EdWorldEdit : ` — с пробелами вокруг двоеточия (события 1, 2, 5, 6),
> `EdWorldEdit:` — без пробела (событие 4).

### 1.3. Заливка (событие 5)

- Заполняется кубоид между `pos1` и `pos2` (включая обе позиции; границы = min/max по каждой оси).
- Блок заливки — **нода, на которую пришёлся третий ПКМ-клик** (не предмет в руке).
- Правило пропуска («пропуская занятые, кроме воды и травы, их затирает»):

| Нода в кубоиде | Действие |
|---|---|
| `air` | заполняется |
| вода (любая: `default:water_source/flowing`, `mcl_core:water_source`, `mcl_core:river_water_*`) | **затирается** блоком заливки |
| трава (любая: `default:grass_1..5`, `default:dirt_with_grass*`, `mcl_core:grass_block`, `mcl_core:short_grass` и т.п.) | **затирается** блоком заливки |
| любой другой занятый блок (камень, дерево, лава, сундук…) | **пропускается** (остаётся как есть) |
| `ignore` (незагруженный чанк) | пропускается |

- Определение «вода/трава» — по паттерну имени ноды (содержит `water` / `grass`), что покрывает и MTG (`default:`), и VoxeLibre (`mcl_core:`). *(Решение 2)*
- У заполняемых нод копируется `param2` исходной ноды (повороты лестниц/плит сохраняются).

---

## 2. Архитектура мода

Отдельный самодостаточный мод в папке `edwe/` (внутри репозитория, но при
установке копируется как самостоятельный мод — например в
`L:\games\luanti-5.14.0-win64\mods\edwe\` или в `worldmods/`).

> **Важно:** НЕ класть `edwe/` внутрь папки мода vbots2 в рантайме — Luanti
> детектит моды только одним уровнем вложенности; репозиторий целиком уже является
> модом `vbots2`, вложенная папка будет проигнорирована.

```
edwe/
  mod.conf            -- name = edwe, description
  init.lua            -- регистрация инструмента, обработчики кликов, состояние, globalstep
  fill.lua            -- is_water() / is_grass() / fill_cuboid()
  settingtypes.txt    -- лимит нод на заливку (опционально)
  textures/edwe_wooden_axe.png
  license.txt
  README.md
```

### 2.1. Состояние (per-player)

```lua
edwe = {}
edwe.player = {}   -- edwe.player[name] = { pos1 = vector, pos2 = vector }
```

- Фаза выводится из полей: нет `pos1` → фаза 0; есть `pos1`, нет `pos2` → фаза 1;
  есть оба → фаза 2 (готово к заливке).
- Чистка при выходе игрока: `minetest.register_on_leaveplayer` → удалить запись.

### 2.2. Регистрация инструмента

```lua
minetest.register_tool("edwe:wooden_axe", {
    description = "EdWorldEdit Wooden Axe",
    inventory_image = "edwe_wooden_axe.png",
    groups = {},
    on_use  = edwe_handle_lmb,   -- ЛКМ: отметка pos1
    on_place = edwe_handle_rmb,  -- ПКМ: pos2 / заливка
    -- tool_capabilities не задаём: топорик ничего не копает
})
```

**Почему это работает:**
- Наличие `on_use` у инструмента отключает дефолтное копание по ЛКМ (движок
  вызывает `on_use` вместо копания).
- Наличие `on_place` перехватывает ПКМ по ноде: `on_rightclick` ноды (сундук,
  печь…) при этом НЕ вызывается — топорик не открывает контейнеры.
- Оба обработчика проверяют `pointed_thing.type == "node"`; клик по воздуху
  (`"nothing"`) или объекту (`"object"`) — no-op.

---

## 3. Обработчики кликов (псевдокод)

```lua
-- ЛКМ
if pointed_thing.type ~= "node" then return itemstack end
st.pos1 = pointed_thing.under
chat(player, "EdWorldEdit :  first point set.")

-- ПКМ
if pointed_thing.type ~= "node" then return itemstack end
if not st.pos1 then
    return itemstack                          -- событие 3: игнор
elseif not st.pos2 then
    st.pos2 = pointed_thing.under
    chat(player, "EdWorldEdit: second point set. Choose item to copy.")
else
    local fill = minetest.get_node(pointed_thing.under)   -- блок «отмечен третьим»
    fill_cuboid(player, st.pos1, st.pos2, fill)
    edwe.player[name] = nil                   -- сброс
    chat(player, "EdWorldEdit : copy done")
end
```

---

## 4. Детект смены инструмента (событие 6)

Проверено: **в Luanti нет** колбэка «игрок сменил предмет в руке»
(`register_on_player_change_item` не существует — подтверждено поиском по GitHub
и документации). Поэтому:

```lua
minetest.register_globalstep(function()
    for name, st in pairs(edwe.player) do
        local player = minetest.get_player_by_name(name)
        if player and player:get_wielded_item():get_name() ~= "edwe:wooden_axe" then
            edwe.player[name] = nil
            minetest.chat_send_player(name, "EdWorldEdit : cancel")
        end
    end
end)
```

- Итерация только по игрокам с активным состоянием (обычно 0–1) — оверхед минимален.
- Альтернатива (хранить состояние в метаданных самого стака топорика) отклонена:
  она не даёт послать `cancel` при смене инструмента и «восстанавливает» старое
  состояние при возврате к тому же стаку — противоречит ТЗ.

---

## 5. Заливка (`fill.lua`)

```lua
function fill_cuboid(player_name, pos1, pos2, fill)
    local minp, maxp = сортировка pos1/pos2 по осям
    local count = (maxp.x-minp.x+1) * (maxp.y-minp.y+1) * (maxp.z-minp.z+1)
    if count > edwe.max_nodes then
        chat(player_name, "EdWorldEdit : region too big (" .. count .. " nodes, max " .. edwe.max_nodes .. ")")
        return false
    end
    local list = {}
    for x = minp.x, maxp.x do
      for y = minp.y, maxp.y do          -- вложенные циклы по осям
        for z = minp.z, maxp.z do
          local node = minetest.get_node({x=x, y=y, z=z})
          if node.name ~= "ignore"
          and (node.name == "air" or is_water(node.name) or is_grass(node.name))
          and not minetest.is_protected({x=x, y=y, z=z}, player_name) then
              table.insert(list, {x=x, y=y, z=z})
          end
        end                              -- z
      end                                -- y
    end                                  -- x
    minetest.bulk_set_node(list, fill)   -- fill копирует param2 из источника
end
```

- `minetest.bulk_set_node` — быстрее `set_node` в цикле; принимает `{name=…, param2=…}`.
- `edwe.max_nodes` — настройка из `settingtypes.txt` (по умолчанию 10000).
- Проверка `minetest.is_protected` — защищённые ноды не трогаем. *(Решение 3)*

---

## 6. Краевые случаи

| Случай | Поведение |
|---|---|
| ПКМ до ЛКМ | игнор (событие 3) |
| ЛКМ/ПКМ по воздуху или по существу | no-op |
| pos1 == pos2 | заливается 1 нода |
| Клик по ноде внутри кубоида (третий клик) | заливка этой нодой (в т.ч. водой — «залить водой» тоже валидно) |
| Регион больше лимита | отказ + сообщение, состояние сохраняется |
| Незагруженные чанки (`ignore`) | пропускаются |
| Защита (areas/protection) | пропускается |
| Выход игрока с активным состоянием | состояние очищается |
| Игрок бросил/потерял топорик, взял другой | globalstep → `cancel` |
| Взятие другого топорика (новый стак) | состояние не переносится (это нормально: state per-player, а не per-stack) |
| Survival: расход блоков из инвентаря | НЕ расходует (заливка бесплатная, как в креативе) *(Решение 4)* |

---

## 7. Принятые решения

| # | Вопрос | Решение |
|---|--------|---------|
| 1 | Как получить топорик | Крафт как у деревянного топора + вкладка Creative |
| 2 | Что считать водой/травой | Паттерн имени: содержит `water` / `grass` (покрывает `default:` и `mcl_core:`) |
| 3 | Уважать ли защиту | Да, `minetest.is_protected` — защищённые ноды пропускаем |
| 4 | Расходовать ли блоки в survival | Нет, заливка бесплатная в обоих режимах (по ТЗ «в креативе или нормальной игре — заполняет») |

---

## 8. План работ (пошаговый)

### Этап 0: Каркас
- [ ] **0.1.** Создать `edwe/` (mod.conf: `name = edwe`, license.txt, README.md)
- [ ] **0.2.** `settingtypes.txt` с `edwe.max_nodes` (по умолч. 10000)

### Этап 1: Инструмент и отметки
- [ ] **1.1.** `init.lua`: `minetest.register_tool("edwe:wooden_axe", …)` с `on_use`/`on_place`
- [ ] **1.2.** ЛКМ: pos1 + сообщение `EdWorldEdit :  first point set.`
- [ ] **1.3.** ПКМ: pos2 + сообщение `EdWorldEdit: second point set. Choose item to copy.`
- [ ] **1.4.** Крафт (3 доски + 2 палки) → `edwe:wooden_axe`

### Этап 2: Заливка
- [ ] **2.1.** `fill.lua`: `is_water()`, `is_grass()` (паттерны `water`/`grass`)
- [ ] **2.2.** `fill_cuboid()`: кубоид, пропуск занятых, затирание воды/травы, `bulk_set_node`
- [ ] **2.3.** Третий ПКМ: выбрать блок-заливку, выполнить, сброс, `EdWorldEdit : copy done`
- [ ] **2.4.** Лимит региона + сообщение об отказе; `is_protected`

### Этап 3: Сброс состояния
- [ ] **3.1.** `register_globalstep`: смена предмета → сброс + `EdWorldEdit : cancel`
- [ ] **3.2.** `register_on_leaveplayer`: чистка `edwe.player[name]`

### Этап 4: Текстуры и полировка
- [ ] **4.1.** `textures/edwe_wooden_axe.png` (16×16, деревянный топорик)
- [ ] **4.2.** Проверка: клик по воздуху/существу — no-op; pos1 == pos2 — 1 нода

### Этап 5: Тестирование (см. §9)

---

## 9. Тестирование

1. **Синтаксис:** `.\luac\luac54.exe -p init.lua && .\luac\luac54.exe -p fill.lua` — обе команды с кодом 0.
2. **Запуск:** скопировать `edwe/` в моды игры, включить в `world.mt`, запустить
   `bin\luanti.exe --server --world worlds/2` (= `runserver.bat`); при ошибке —
   первый `ServerError`/`ModError` искать в `debug.txt`.
3. **Ручной сценарий (в игре):**
   - [ ] ЛКМ по блоку → `EdWorldEdit :  first point set.`
   - [ ] ПКМ по блоку → `EdWorldEdit: second point set. Choose item to copy.`
   - [ ] ПКМ по третьему блоку → кубоид заполнен, `EdWorldEdit : copy done`, состояние сброшено
   - [ ] Занятые блоки (камень) в кубоиде остались; воздух заполнен
   - [ ] Вода и трава в кубоиде затёрты блоком заливки
   - [ ] Смена предмета в руке после 1-й/2-й отметки → `EdWorldEdit : cancel`, отметки сброшены
   - [ ] ПКМ до ЛКМ — ничего не происходит
   - [ ] ЛКМ по существу/воздуху — ничего не происходит
   - [ ] Топорик не копает блоки, не открывает сундуки/печи
   - [ ] Работает и в креативе, и в survival
   - [ ] Защищённая территория не заливается
   - [ ] Регион больше лимита → отказ с сообщением

---

## 10. Открытые вопросы

1. Нужен ли крафт, или топорик только из Creative? *(по умолчанию: и то, и то)*
2. «Трава» — только `dirt_with_grass` или и растения `grass_1..5`? *(по умолчанию:
   всё, что содержит `grass` — перезаписываем)*
3. Нужна ли защита `is_protected`? *(по умолчанию: да)*