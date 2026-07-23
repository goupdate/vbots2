# visual-bots — Архитектура и План Расширения (vbots2)

## 1. Обзор

**visual-bots** — мод для Luanti (Minetest), реализующий визуальное программирование роботов-черепашек. Робот выполняет программу, собранную из предметов-команд в слотах инвентаря.

### Файлы (6 .lua + mod.conf)

| Файл | Назначение |
|---|---|
| `mod.conf` | Метаданные: name=vbots |
| `init.lua` | Точка входа. Глобальная таблица `vbots`, `vbots.bot_info`, создание/восстановление ботов, toggle on/off, save/load программ через `mod_storage` |
| `register_bot.lua` | **Ядро.** Движение, копание, строительство, диспетчер команд (`bot_parsecommand`), главный цикл (`bot_handletimer`), регистрация нод `vbots:on`/`vbots:off` |
| `register_commands.lua` | Регистрация предметов-команд (craftitems) с группой `bot_commands` |
| `formspec.lua` | Генерация GUI (16×9, панель команд, инвентарь, 6 подпрограмм) |
| `formspec_handler.lua` | Обработка форм: вставка команд, run/save/load/reset, управление подпрограммами |
| `register_joinleave.lua` | Очистка `vbots.bot_info` при выходе игрока |

---

## 2. Архитектура Исполнения

### 2.1. Модель: Timer-Driven State Machine

Робот — нода с таймером. При включении:

```
bot_togglestate(pos, "on")
  → timer:start(1/steptime)
  → PC=0, PR=0, stack=""
```

### 2.2. Главный Цикл (`bot_handletimer`, register_bot.lua:297-348)

```
На каждом тике:
  1. Прочитать PC, PR из метаданных ноды
  2. invname = "p"..PR            — выбрать инвентарь текущей подпрограммы
  3. command = inv:get_stack(invname, PC)  — прочитать команду в слоте PC
  4. Если repeat == 0:
       a. Пропустить пустые слоты (while command=="" → PC++)
       b. Заглянуть в следующий слот — если vbots:number_N, repeat=N-1, PC++
     Иначе (repeat > 0):
       c. Перечитать команду в PC-1, repeat--
  5. Если PC < 56:
       bot_parsecommand(pos, command)  — выполнить
       return true  (таймер продолжается)
     Иначе (PC >= 56, конец программы):
       Если PR != 0 → pull_state(pos)  — возврат из подпрограммы
       Иначе → bot_togglestate(pos, "off")  — выключение
```

**Ключевые моменты:**
- PC всегда продвигается на +1 после выполнения (или на +N при пропуске пустых)
- Никаких условных переходов НЕТ
- Единственный flow control — repeat (числа 2-9 повторяют предыдущую команду)

### 2.3. Диспетчер Команд (`bot_parsecommand`, register_bot.lua:224-284)

Линейная цепочка `if/elseif` по имени предмета:

| Команда | Действие |
|---|---|
| `move_forward` | `move_bot(pos, "f")` — вперёд по facedir |
| `move_backward` | `move_bot(pos, "b")` — назад |
| `move_up` | `move_bot(pos, "u")` — y+1 |
| `move_down` | `move_bot(pos, "d")` — y-1 |
| `move_home` | `position_bot(pos, home)` — телепорт домой |
| `turn_clockwise` | param2 = (param2+1)%4 |
| `turn_anticlockwise` | param2 = (param2-1)%4 |
| `turn_random` | Случайный поворот |
| `mode_dig` | Копать вперёд + движение вперёд |
| `mode_dig_down` | Копать вниз + движение вниз |
| `mode_dig_up` | Копать вверх + движение вверх |
| `mode_build` | Поставить блок позади |
| `mode_build_down` | Поставить блок снизу |
| `mode_build_up` | Поставить блок сверху |
| `mode_speed` | Изменить steptime |
| `run_1`…`run_6` | Вызов подпрограммы (push_state, PR=N, PC=0) |

### 2.4. Система Направлений

Бот использует `paramtype2 = "facedir"` (значения 0-3):
- `minetest.facedir_to_dir(node.param2)` → вектор направления
- **Вперёд**: `{x = pos.x - dir.x, z = pos.z - dir.z}`
- **Назад**: `{x = pos.x + dir.x, z = pos.z + dir.z}`
- **Вверх/вниз**: всегда ±1 по Y

### 2.5. Стек Вызовов (Подпрограммы)

- `push_state(pos, PC, PR, repeat)` — добавляет `"PC,PR,repeat,"` в начало строки `stack`
- `pull_state(pos)` — извлекает первые 3 значения из стека
- LIFO: последний вошёл — первый вышел

### 2.6. Обнаружение Блоков (как это делается сейчас)

Во всех функциях — ad-hoc, нет единого «сенсора»:

```lua
-- Шаблон (из bot_dig, register_bot.lua:155-159):
local node = minetest.get_node(pos)
local dir = minetest.facedir_to_dir(node.param2)
local front_pos = {x = pos.x - dir.x, y = pos.y, z = pos.z - dir.z}
local front_node = minetest.get_node(front_pos)
-- front_node.name — имя блока впереди
```

### 2.7. Условная Логика: ЗАКОММЕНТИРОВАННЫЕ АРТЕФАКТЫ

В `register_commands.lua:30-36` и `formspec.lua:48` есть закомментированные команды:
```
case_end, case_failure, case_success, case_yes, case_no, case_test, case_repeat
```

Это доказывает, что автор **планировал** условную систему, но **не реализовал** диспетчеризацию. Кода для них в `bot_parsecommand` никогда не было.

### 2.8. Метаданные Ноды Бота

| Поле | Тип | Назначение |
|---|---|---|
| `key` | string | Уникальный ID бота |
| `owner` | string | Владелец |
| `name` | string | Имя бота |
| `PC` | int | Program Counter (1-56) |
| `PR` | int | Program Register — номер подпрограммы (0-6) |
| `repeat` | int | Счётчик повторов (0 = без повтора) |
| `stack` | string | Стек вызовов `"PC,PR,repeat,..."` |
| `steptime` | int | Множитель скорости |
| `home` | string | Сериализованная позиция установки |
| `program` | int | Текущая редактируемая подпрограмма |
| `panel` | int | Режим панели (0=команды, 1=инвентарь) |

Инвентари: `p0`…`p6` (56 слотов, программы), `main` (32 слота, материалы), `trash` (1 слот)

---

## 3. Что Хотим Сделать: vbots2

### 3.1. Цель

Создать мод `vbots2` на базе `visual-bots` с добавлением **двух условных команд визуального программирования**.

### 3.2. Команда 1: `=?` — «Впереди данный блок?»

**Семантика:** если блок впереди бота совпадает с указанным — выполнить следующую за аргументом команду, иначе пропустить её.

**Формат в программе (4 слота):**
```
[ =? ] [ A ] [ B ] [ C ]
 слот0  слот1  слот2  слот3
```
- **Слот 0** — команда `=?` (vbots2:eq_check)
- **Слот 1** — аргумент: предмет-блок (например, `default:stone`) — **что** ищем впереди
- **Слот 2** — команда B: выполняется только если условие истинно
- **Слот 3** — команда C: выполняется всегда

**Пример:** `?ABC` — если впереди бота блок A, то выполнится B, затем C. Иначе только C.

**Псевдокод:**
```
функция eq_check(pos):
  front_node = get_front_node(pos)
  expected  = read_slot(PC + 1)   -- предмет-блок из слота-аргумента
  если front_node.name == expected:
    PC += 1          -- пропустить слот-аргумент, на следующем тике выполнится B
  иначе:
    PC += 2          -- пропустить слот-аргумент И команду B, на следующем тике — C
```

### 3.3. Команда 2: `<>?` — «НЕ впереди»

**Семантика:** то же, что `=?`, но с инверсией. Если блок впереди НЕ совпадает с указанным — выполнить следующую команду.

**Формат:** идентичен `=?`:
```
[ <>? ] [ A ] [ B ] [ C ]
```

**Псевдокод:**
```
функция neq_check(pos):
  front_node = get_front_node(pos)
  expected  = read_slot(PC + 1)
  если front_node.name != expected:
    PC += 1          -- условие истинно, выполняем B
  иначе:
    PC += 2          -- условие ложно, пропускаем B
```

### 3.4. Механика Пропуска (Skip) — Ключевое Архитектурное Изменение

В текущей архитектуре PC всегда продвигается на +1 за тик. Нужен механизм **условного продвижения PC** на величину > 1.

**Решение:** добавить мета-поле `skip` (int) в метаданные ноды бота.

В `bot_handletimer`, после вызова `bot_parsecommand`:
```
skip = meta:get_int("skip")
если skip > 0:
  PC = PC + skip
  meta:set_int("skip", 0)
иначе:
  PC = PC + 1   -- стандартное поведение
```

А `bot_parsecommand` для условных команд устанавливает `meta:set_int("skip", N)` вместо продвижения PC.

### 3.5. Функция `get_front_node(pos)` — Общий Сенсор

Выделить повторяющийся паттерн обнаружения блока впереди в отдельную функцию:

```lua
local function get_front_node(pos)
  local node = minetest.get_node(pos)
  local dir = minetest.facedir_to_dir(node.param2)
  local front_pos = {x = pos.x - dir.x, y = pos.y, z = pos.z - dir.z}
  return minetest.get_node(front_pos)
end
```

### 3.6. Что Нужно Изменить

| Файл | Изменения |
|---|---|
| `mod.conf` | Переименовать `name = vbots2` |
| `init.lua` | Заменить `vbots` → `vbots2` во всех упоминаниях (глобальная таблица, неймспейс) |
| `register_commands.lua` | Добавить `register_command("eq_check", "Is block ahead?", "vbots2_eq_check.png")` и `register_command("neq_check", "Is NOT block ahead?", "vbots2_neq_check.png")` |
| `formspec.lua` | Добавить кнопки `eq_check` и `neq_check` в панель команд |
| `register_bot.lua` — `get_front_node` | Новая общая функция |
| `register_bot.lua` — `bot_parsecommand` | Добавить 2 `elseif` для `vbots2:eq_check` и `vbots2:neq_check` |
| `register_bot.lua` — `bot_handletimer` | Добавить логику `skip` после вызова `bot_parsecommand` |
| `register_bot.lua` — `bot_init` | Инициализировать `skip = 0` в метаданных |
| Текстуры | Создать иконки `vbots2_eq_check.png` и `vbots2_neq_check.png` |

### 3.7. Детальный План Работ (Пошаговый)

#### Этап 0: Подготовка
- [ ] **Шаг 0.1.** Скопировать `visual-bots/` → `vbots2/`
- [ ] **Шаг 0.2.** В `mod.conf`: `name = vbots2`, обновить `description`
- [ ] **Шаг 0.3.** Глобальный реплейс `vbots` → `vbots2` во всех .lua файлах (неймспейс команд, глобальная таблица, mod_storage)

#### Этап 1: Новые Команды (Регистрация + GUI)
- [ ] **Шаг 1.1.** `register_commands.lua`: добавить `register_command("eq_check", "Is block ahead?", "vbots2_eq_check.png")` и `register_command("neq_check", "Is NOT block ahead?", "vbots2_neq_check.png")`
- [ ] **Шаг 1.2.** `formspec.lua`: добавить кнопки `eq_check` и `neq_check` в таблицу `commands[1]` (секция "Special" или новая строка)
- [ ] **Шаг 1.3.** Создать текстурки-заглушки 16×16 (или скопировать/отредактировать существующие)

#### Этап 2: Ядро — Логика Исполнения
- [ ] **Шаг 2.1.** `register_bot.lua`: добавить функцию `get_front_node(pos)` (см. 3.5)
- [ ] **Шаг 2.2.** `register_bot.lua` — `bot_parsecommand`: добавить обработчики:
  - `vbots2:eq_check`:
    1. `front = get_front_node(pos)`
    2. `expected = inv:get_stack("p"..PR, PC+1):get_name()`
    3. Если `front.name == expected` → `meta:set_int("skip", 1)` (пропускаем только слот-аргумент)
    4. Иначе → `meta:set_int("skip", 2)` (пропускаем аргумент + команду B)
  - `vbots2:neq_check`: аналогично, но с `front.name ~= expected`
- [ ] **Шаг 2.3.** `register_bot.lua` — `bot_handletimer`: 
  - После `bot_parsecommand(pos, command)` (строка ~336) добавить:
    ```lua
    local skip = meta:get_int("skip")
    if skip > 0 then
      PC = PC + skip
      meta:set_int("skip", 0)
    end
    ```
  - Учесть, что стандартное `PC = PC + 1` (строка ~339) не должно выполняться при `skip > 0`
- [ ] **Шаг 2.4.** `register_bot.lua` — `bot_init`: добавить `meta:set_int("skip", 0)` при создании бота

#### Этап 3: Обработка Краевых Случаев
- [ ] **Шаг 3.1.** Пустой слот-аргумент → `expected == ""` → замена на `"air"`. Означает проверку «впереди воздух?»
- [ ] **Шаг 3.2.** Что если после аргумента нет команды (конец программы)? → проверить `PC+2 >= 56`, не пытаться выполнить несуществующую команду
- [ ] **Шаг 3.3.** Обработка внутри подпрограмм: `skip` должен работать и при `PR > 0`

#### Этап 4: Тестирование
- [ ] **Шаг 4.1.** Запустить Luanti с модом `vbots2`
- [ ] **Шаг 4.2.** `=?` с совпадающим блоком: `[eq_check][default:dirt][move_forward][turn_clockwise]` — бот перед землёй → движется вперёд, затем поворачивает
- [ ] **Шаг 4.3.** `=?` с несовпадающим блоком: тот же код, бот перед воздухом → только поворачивает
- [ ] **Шаг 4.4.** `<>?` с несовпадающим блоком: бот перед воздухом, ищет `default:stone` → движется вперёд
- [ ] **Шаг 4.5.** `<>?` с совпадающим блоком: бот перед `default:stone` → пропускает движение
- [ ] **Шаг 4.6.** Проверить в подпрограммах

---

## 4. Принятые Решения

| Вопрос | Решение |
|---|---|
| Формат аргумента | **Конкретный блок.** Пользователь кладёт предмет-блок (например `default:stone`) в слот рядом с командой. Сравнение по `front_node.name == item_name`. |
| Пустой слот-аргумент | **Трактуется как `"air"`.** `expected = inv:get_stack(...):get_name()` → если пусто, `expected = "air"`. Означает «впереди ничего нет». |
| Иконки | **Заглушки.** Одноцветные квадраты 16×16 с текстом `=?` и `<>?`. |
