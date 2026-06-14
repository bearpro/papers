# MDL Language Reference

Русскоязычный справочник по языку `mdl` из репозитория `bearpro/standard-contradictions`.

Дата среза: 2026-06-08. Документ описывает язык по текущей реализации: грамматике `MDL.g4`, AST builder, semantic checker/linter, type inference, point-wise runtime, core translator, finite-horizon solver и стандартной библиотеке. Это практический reference текущего поведения инструментов, а не независимая формальная спецификация.

## Содержание

1. [Модель языка](#1-модель-языка)
2. [Структура файла и модуля](#2-структура-файла-и-модуля)
3. [Лексика](#3-лексика)
4. [Имена, области видимости, import и open](#4-имена-области-видимости-import-и-open)
5. [Типы](#5-типы)
6. [Паттерны](#6-паттерны)
7. [Выражения](#7-выражения)
8. [Блоки](#8-блоки)
9. [Верхнеуровневые декларации](#9-верхнеуровневые-декларации)
10. [Правила, деонтика и defeasible reasoning](#10-правила-деонтика-и-defeasible-reasoning)
11. [Темпоральная логика конечной трассы](#11-темпоральная-логика-конечной-трассы)
12. [Система типов](#12-система-типов)
13. [Runtime-семантика](#13-runtime-семантика)
14. [Core translation / DDL-LTLf JSON](#14-core-translation--ddl-ltlf-json)
15. [Standard library](#15-standard-library)
16. [CLI](#16-cli)
17. [Грамматическая шпаргалка](#17-грамматическая-шпаргалка)
18. [Примеры](#18-примеры)
19. [Особенности и ограничения реализации](#19-особенности-и-ограничения-реализации)
20. [Карта исходников](#20-карта-исходников)

---

## 1. Модель языка

`mdl` — ML-inspired язык для описания нормативных положений. В текущем проекте он совмещает:

- чистые вычисления: значения, функции, рекурсия, алгебраические типы данных, записи, кортежи, pattern matching;
- деонтические правила: `O` obligation, `P` permission, `F` prohibition;
- defeasible reasoning: `strict`, `defeasible`, `defeater`, `override`;
- темпоральные формулы конечной трассы: `always`, `eventually`, `next`, `initially`, `until`, `last`;
- перевод в компактное DDL-LTLf core JSON;
- bounded solving через Z3 на конечном горизонте.

Типичный pipeline:

```text
.mdl source
  -> lexer/parser
  -> AST
  -> format/lint/run/translate/solve
  -> DDL-LTLf core JSON
  -> finite-trace solver
```

Важное разделение инструментов:

- `run` — point-wise runtime. Он исполняет обычные выражения, функции, значения, факты, pattern matching и часть stdlib/builtins. Он не моделирует полноценную темпоральную семантику.
- `translate` — строит backend-neutral core JSON.
- `solve` — кодирует правила и темпоральные формулы на конечном горизонте и проверяет satisfiability/модель.

---

## 2. Структура файла и модуля

Каждый `.mdl` файл — модуль. Программа начинается с необязательных аннотаций и обязательного `module`.

```mdl
@optional-module-annotation
module my.policy

import "std/collections.mdl"
open std.collections

let x = 1
```

Общий порядок:

```ebnf
program ::= newlines? annotations moduleDecl newlines? topItem* EOF
topItem ::= annotations (importDecl | openDecl | declaration) newlines?
```

### 2.1 `module`

```mdl
module std.collections
module tax.vat.rules
```

`module` принимает qualified name: name tokens через точку.

```ebnf
moduleDecl ::= "module" qualifiedName
qualifiedName ::= nameToken ("." nameToken)*
```

`module` обязателен и идёт перед всеми top-level items.

### 2.2 `import`

```mdl
import "std/collections.mdl"
import "../other/policy.mdl"
```

`import` принимает строковый путь, а не имя модуля.

```ebnf
importDecl ::= "import" STRING
```

Для stdlib loader умеет резолвить пути вида `std/...` относительно stdlib directory. В stdlib imports запрещены `..`.

### 2.3 `open`

```mdl
open std.collections
```

`open` вносит экспортируемые имена модуля в короткую область видимости текущего модуля. Например после `open std.collections` можно писать `List.Empty()` вместо `std.collections.List.Empty()`.

```ebnf
openDecl ::= "open" qualifiedName
```

Если несколько `open` вносят конфликтующее короткое имя, semantic checker сообщает неоднозначность.

### 2.4 Аннотации

Аннотация — токен, начинающийся с `@` и продолжающийся до конца строки.

```mdl
@source: article 5
@label: payment-due
rule O pay_when_due when invoice_issued: paid eventually
```

Аннотации разрешены:

- перед `module`;
- перед любым top-level item: `import`, `open`, `type`, `let`, `func`, `entity`, `rule`, `override`, `fact`.

В текущей реализации аннотации сохраняются в AST/core, но сами не меняют type checking, runtime или solver-семантику.

---

## 3. Лексика

### 3.1 Пробелы и indentation

`mdl` использует значимые переводы строк и отступы для блоков. Блок после `:` может быть inline expression или indented block.

```mdl
func inc(x: int) -> int: x + 1

func abs(x: int) -> int:
  if x < 0 then -x else x
```

Lexer создаёт `INDENT`/`DEDENT` на основе отступов. Для `case` builder дополнительно проверяет, что arms находятся глубже, чем строка `case`.

### 3.2 Комментарии

```mdl
# full-line comment
let x = 1 # trailing comment
```

Комментарий начинается с `#` и продолжается до конца строки.

### 3.3 Идентификаторы

```ebnf
IDENT ::= [A-Za-z_] [A-Za-z0-9_']*
```

Примеры:

```mdl
let x = 1
let _internal = 2
let value' = 3
```

### 3.4 Keywords и специальные токены

```text
module import open type let func entity rule fact override
strict defeasible defeater otherwise when
if then else case in
true false not and or implies
O P F
always eventually next initially until last
```

`nameToken` в грамматике допускает `IDENT`, а также `true`, `false`, `last`, `O`, `P`, `F`. Практически лучше не использовать эти слова как имена пользовательских сущностей, хотя grammar это допускает в некоторых позициях.

### 3.5 Строки

```mdl
let s = "hello"
let quoted = "a \"quoted\" word"
```

Строковый токен допускает backslash escapes. Текущий AST builder **не декодирует** escape-последовательности как стандартные `\n`, `\t` и т.п.; escaped character сохраняется с backslash. Например исходный текст `"\n"` становится строкой из двух символов `\` и `n`.

### 3.6 Числа

```mdl
let i = 123       # int
let d = 12.34     # decimal
let r = 3/7       # rat
```

```ebnf
INT     ::= [0-9]+
DECIMAL ::= [0-9]+ "." [0-9]+
RAT     ::= [0-9]+ "/" [0-9]+
```

Отрицательное число — unary expression, а не отдельный literal token:

```mdl
let n = -42
```

### 3.7 Boolean, unit, `last`

```mdl
true
false
()
last
```

`()` — unit literal. В runtime unit представлен как `None`, в type system как `unit`.

`last` — специальное boolean name для конечной трассы: solver делает его true только на последнем step.

---

## 4. Имена, области видимости, import и open

### 4.1 Qualified names

```mdl
std.collections.List.Empty
my.policy.rule_name
```

Qualified name — цепочка `nameToken` через точку. Точка также используется для field access `expr.field`, но это другая AST-конструкция: qualified name разбирается как `Name`, а postfix `.field` — как `FieldAccess`.

### 4.2 Declaration order

Semantic checker работает order-aware:

- primitive types доступны изначально;
- imports/opens обрабатываются до локальных деклараций;
- top-level declarations становятся доступны по мере прохождения файла;
- top-level `let` не может ссылаться на later declaration;
- функция видит своё собственное имя в теле, поэтому self-recursion поддерживается;
- произвольная mutual recursion без правильного порядка объявлений не гарантируется;
- local `let`, `let ... in`, function parameters и case patterns вводят локальные bindings.

Пример ошибки порядка:

```mdl
let a = b + 1  # b ещё не объявлен
let b = 1
```

Self-recursion:

```mdl
func len<T>(l: List<T>) -> int:
  case l:
    | List.Empty(): 0
    | List.Cons(head, tail): 1 + len(tail)
```

### 4.3 Imports и qualified access

```mdl
import "std/collections.mdl"

let empty = std.collections.List.Empty()
```

Imported module names можно использовать qualified. Loader также регистрирует stdlib modules для semantic checking/solver при наличии stdlib path.

### 4.4 `open` и короткие имена

```mdl
import "std/collections.mdl"
open std.collections

let empty = List.Empty()
```

`open` приносит exported types/values/functions/entities и type constructors в короткую область видимости. При конфликте short name checker выдаёт ambiguity.

### 4.5 Built-in roots/terms

Primitive types:

```text
bool int rat decimal string unit
```

Builtin boolean temporal term:

```text
last
```

`last` предназначен прежде всего для `translate`/`solve`. Point-wise `run` не является полноценной temporal machine.

---

## 5. Типы

### 5.1 Примитивные типы

```text
bool
int
rat
decimal
string
unit
```

Numeric types:

```text
int rat decimal
```

Arithmetic operators требуют numeric operands. При смешении numeric types type inference может выдать warning о numeric coercion.

### 5.2 Type references

```mdl
int
std.collections.List<int>
Map<string, int>
```

```ebnf
typeRef  ::= qualifiedName typeArgs?
typeArgs ::= "<" typeExprList? ">"
```

### 5.3 Type parameters

```mdl
type Box<T> = Box(T)

func id<T>(x: T) -> T: x
```

```ebnf
typeParams ::= "<" nameList ">"
```

### 5.4 Record types

```mdl
{ name: string, age: int }
```

```ebnf
recordType ::= "{" typeFieldList? "}"
typeField  ::= nameToken ":" typeExpr
```

Пример:

```mdl
func adult(p: { name: string, age: int }) -> bool:
  p.age >= 18
```

### 5.5 Tuple types

```mdl
(int, string)
(bool, int, string)
```

`(T)` — grouping, не tuple. Одноэлементного tuple-типа нет.

### 5.6 ADT / variants

```mdl
type Option<T> = None(unit) | Some(T)
type Result<T, E> = Ok(T) | Err(E)
type Shape = Circle(radius: decimal) | Point(decimal, decimal)
```

`typeDefinition` — либо record type, либо один или несколько variants через `|`.

```ebnf
typeDecl       ::= "type" nameToken typeParams? "=" typeDefinition
typeDefinition ::= recordType | variant ("|" variant)*
variant        ::= nameToken "(" variantFieldList ")"
variantField   ::= nameToken ":" typeExpr | typeExpr
```

Variant fields могут быть named или unnamed.

### 5.7 Record type vs record constructor

Record type:

```mdl
{ name: string, age: int }
```

Record constructor expression:

```mdl
Person { name = "Ada", age = 42 }
```

Record constructor должен иметь base expression типа `Name`. Нельзя написать `(Person) { ... }`.

---

## 6. Паттерны

Паттерны используются в function parameters, local lets, `let ... in`, `case`.

### 6.1 Wildcard

```mdl
_
```

Сопоставляется с любым значением и не вводит имя.

### 6.2 Variable pattern

```mdl
x
name
```

Связывает значение с именем, если имя не constructor-like.

### 6.3 Literal pattern

```mdl
0
1/2
3.14
"ok"
()
```

Сопоставляется по равенству literal value.

### 6.4 Tuple pattern

```mdl
(a, b)
(_, x, y)
```

Требует tuple value той же длины. `(p)` — grouping, не одноэлементный tuple pattern.

### 6.5 Record pattern

```mdl
{ name }
{ name = n, age = a }
```

`{ field }` берёт поле `field` и связывает его с переменной `field`.

`{ field = pattern }` сопоставляет поле с указанным pattern.

Пример:

```mdl
func adult(p: { name: string, age: int }) -> bool:
  case p:
    | { age = a } when a >= 18: true
    | _: false
```

### 6.6 Constructor pattern

```mdl
List.Empty()
List.Cons(head, tail)
Option.Some(x)
Option.None()
```

Qualified names и имена, локальная часть которых начинается с заглавной буквы, builder трактует как constructor patterns. Если не-constructor-like имя используется с `(...)` в pattern position, builder выдаёт parse error.

### 6.7 Guards

```mdl
case n:
  | x when x < 0: -x
  | x: x
```

Guard должен иметь тип `bool`. Runtime проверяет arms сверху вниз: pattern match, затем guard.

---

## 7. Выражения

Главное правило:

```ebnf
expr ::= temporalPostfix
```

### 7.1 Приоритеты

От высокого к низкому:

| Приоритет | Конструкция | Ассоциативность |
|---:|---|---|
| 1 | primary: literals, names, `()`, parenthesized, tuple | — |
| 2 | postfix: call `(...)`, field `.x`, record constructor `{...}` | left-to-right |
| 3 | unary `not`, unary `-` | right |
| 4 | `*`, `/`, `%` | left |
| 5 | `+`, `-` | left |
| 6 | `==`, `!=`, `<`, `<=`, `>`, `>=` | left in AST |
| 7 | `until` | left |
| 8 | `and` | left |
| 9 | `or` | left |
| 10 | `implies` | right |
| 11 | postfix temporal `always`, `eventually`, `next`, `initially` | left-to-right nesting |

Следствия:

```mdl
p implies q implies r
# p implies (q implies r)

a < b < c
# (a < b) < c — почти всегда ошибка типов
```

Для chained comparisons пишите:

```mdl
(a < b) and (b < c)
```

### 7.2 Literals и names

```mdl
true
false
123
1/3
12.5
"text"
()
last
x
std.collections.List.Empty
```

### 7.3 Tuples

```mdl
(1, "a")
(true, 1, "x")
```

`(expr)` — grouping. Одноэлементного tuple literal нет.

### 7.4 Calls

```mdl
f(1, 2)
List.Empty()
List.Cons(1, List.Empty())
```

Call — postfix suffix к expression:

```ebnf
postfixSuffix ::= "(" exprList? ")"
```

Callee может быть user function, builtin, stdlib constructor или ADT constructor.

### 7.5 Field access

```mdl
p.name
module.value
```

Для record values runtime ожидает dict-like value. Checker проверяет наличие поля в record-like type/module field chain.

### 7.6 Record constructor

```mdl
Person { name = "Ada", age = 42 }
```

```ebnf
recordConstructorFields ::= "{" recordConstructorFieldList? "}"
recordConstructorField  ::= nameToken "=" expr
```

Checker валидирует duplicate/unknown/missing fields и типы значений полей.

### 7.7 Unary operators

```mdl
not p
-x
```

`not` требует `bool`, возвращает `bool`.

Unary `-` требует numeric operand.

### 7.8 Arithmetic

```mdl
a + b
a - b
a * b
a / b
a % b
```

Operands должны быть numeric (`int`, `rat`, `decimal`). Runtime использует Python arithmetic. Type inference унифицирует numeric types и может предупреждать о coercion.

### 7.9 Comparisons

```mdl
a == b
a != b
a < b
a <= b
a > b
a >= b
```

Comparison result — `bool`.

### 7.10 Boolean operators

```mdl
p and q
p or q
p implies q
```

Operands — `bool`, result — `bool`.

Runtime short-circuits через Python semantics. `implies` эквивалентно `(not p) or q`.

### 7.11 `if`

```mdl
if condition then expr1 else expr2
```

Condition должен быть `bool`; ветки должны иметь общий тип. Runtime вычисляет только выбранную ветку.

### 7.12 `let ... in`

```mdl
let pattern : Type = value in body
let pattern = value in body
```

Пример:

```mdl
let (a, b) = pair in a + b
```

Value вычисляется, сопоставляется с pattern, bindings доступны в body.

### 7.13 `case`

```mdl
case subject:
  | pattern when guard: body
  | pattern: body
```

Семантика runtime:

1. вычислить subject;
2. проверить arms сверху вниз;
3. сопоставить pattern;
4. если есть guard, он должен быть true;
5. вычислить body первого подходящего arm;
6. если ничего не подошло — runtime error `non-exhaustive match`.

Checker требует общий тип arm bodies и boolean guards.

### 7.14 Temporal postfix operators

```mdl
p always
p eventually
p next
p initially
```

Операторы postfix, требуют `bool`, возвращают `bool`.

Важно: из-за grammar temporal postfix имеет самый низкий синтаксический приоритет. Поэтому:

```mdl
p implies q eventually
```

разбирается как:

```mdl
(p implies q) eventually
```

Если нужно `p implies (q eventually)`, ставьте скобки.

### 7.15 `until`

```mdl
p until q
```

`until` — temporal binary operator между comparison и `and` по приоритету. В solver это strong until over finite trace.

---

## 8. Блоки

Блок используется в function body и case arm body.

### 8.1 Inline block

```mdl
func inc(x: int) -> int: x + 1
```

### 8.2 Indented block

```mdl
func f(x: int) -> int:
  let y = x + 1
  let z = y * 2
  z + 1
```

```ebnf
block ::= NEWLINE INDENT blockLetStmt* expr? newlines? DEDENT
        | expr

blockLetStmt ::= "let" pattern typeAnnotation? "=" expr newlines
```

Indented block может иметь несколько local `let` statements и необязательное result expression. Без result expression type checker трактует результат как `unit`; runtime возвращает `None`.

---

## 9. Верхнеуровневые декларации

```ebnf
declaration ::= typeDecl
              | valueDecl
              | funcDecl
              | entityDecl
              | ruleDecl
              | priorityDecl
              | factDecl
```

### 9.1 `type`

```mdl
type Option<T> = None(unit) | Some(T)
type Person = Person({ name: string, age: int })
type PersonRecord = { name: string, age: int }
```

`type` объявляет record type или ADT variants.

### 9.2 `let`

```mdl
let x = 1
let greeting: string = "hello"
```

```ebnf
valueDecl ::= "let" nameToken typeAnnotation? "=" expr
```

Top-level `let` объявляет значение. Type annotation необязательна.

### 9.3 `func`

```mdl
func add(x: int, y: int) -> int: x + y

func id<T>(x: T) -> T: x
```

```ebnf
funcDecl ::= "func" nameToken typeParams?
             "(" paramList? ")" "->" typeExpr ":" block
param ::= pattern ":" typeExpr
```

Каждый параметр — pattern с обязательной type annotation. Return type обязателен.

Параметр может быть pattern:

```mdl
func sum_pair((a, b): (int, int)) -> int:
  a + b
```

### 9.4 `entity`

```mdl
entity paid: bool
entity amount: int
```

```ebnf
entityDecl ::= "entity" nameToken ":" typeExpr
```

`entity` объявляет named state/trace variable для solver и runtime environment. Runtime инициализирует entity значением `None`, если fact не задаёт значение. Solver создаёт переменную entity на каждом step конечной трассы.

### 9.5 `fact`

```mdl
fact expr
fact name = expr
```

```ebnf
factDecl ::= "fact" (nameToken "=")? expr
```

Bare fact должен иметь тип `bool`:

```mdl
fact invoice_issued
fact amount > 0
```

Targeted fact задаёт значение target:

```mdl
fact paid = false
fact amount = 100
```

Runtime обновляет target value. Solver трактует entity fact как значение entity на всех шагах, а non-entity value fact — на `t = 0`.

### 9.6 `rule`

Есть anonymous и named forms.

Anonymous:

```mdl
rule O: paid eventually
rule F: breach
```

Builder генерирует имя вида:

```text
anonymous_rule_<line>_<counter>
```

Named:

```mdl
rule O pay_when_due when invoice_issued: paid eventually
rule P may_cancel when before_deadline: cancelled
rule F no_late_fee when paid_on_time: late_fee_charged
```

```ebnf
ruleDecl ::= ruleStrength? "rule" ruleBody ("otherwise" expr)?
ruleBody ::= deonticMod ":" expr
           | deonticMod? qualifiedName ("when" expr)? ":" expr
```

Если `when` отсутствует, antecedent считается true.

### 9.7 Rule strength

```mdl
strict rule O absolute: must_hold

defeasible rule O normally_pay when invoice_issued: paid eventually

defeater rule F exception when force_majeure: paid
```

Default strength — `defeasible`.

Допустимые значения:

```text
strict
defeasible
defeater
```

### 9.8 `otherwise`

```mdl
rule O pay_if_invoice when invoice_issued: paid eventually otherwise reviewed
```

`otherwise` — fallback expression. В solver текущая реализация кодирует его как requirement, когда antecedent не применим: `not app -> requirement(otherwise)`.

### 9.9 `override`

```mdl
override specific_rule > general_rule
override r1 > r2 > r3
```

```ebnf
priorityDecl ::= "override" qualifiedName (">" qualifiedName)*
```

Левое правило имеет приоритет над правым. Текущий solver строит defeat pairs по соседним парам цепочки: `r1 > r2 > r3` даёт `(r1, r2)` и `(r2, r3)`, не явную пару `(r1, r3)`.

---

## 10. Правила, деонтика и defeasible reasoning

### 10.1 Rule model

Rule содержит:

- `name`;
- `strength`: `strict`, `defeasible`, `defeater`;
- `modality`: `O`, `P`, `F` или `None`;
- `antecedent`;
- `body`;
- `otherwise`;
- `anonymous`;
- annotations/source span.

Applicability:

```text
app(rule) = antecedent, если antecedent есть
app(rule) = true, если antecedent отсутствует
```

### 10.2 Deontic modalities

```text
O  obligation
P  permission
F  prohibition
```

Solver requirement:

- `O body` требует `body`;
- `F body` требует `not body`;
- `P body` зависит от option `--permission`:
  - `strong`: требует `body`;
  - `ignore`: не добавляет requirement.

### 10.3 Strict

`strict` rules не defeated как lower rules.

```mdl
strict rule O absolute: must_hold
```

### 10.4 Defeasible

`defeasible` — default. Такие правила могут быть defeated более приоритетными применимыми правилами.

```mdl
rule O normally_pay when invoice_issued: paid eventually
```

### 10.5 Defeater

`defeater` участвует в defeat relation, но сам не добавляет substantive requirement: requirement компилируется как `true`.

```mdl
defeater rule F exception when force_majeure: paid
```

### 10.6 Labels и defeat constraints

Упрощённая схема solver:

```text
label -> app
(app && no_defeat) -> label
label -> requirement(rule)
```

Priority declaration создаёт defeat relation между higher и lower rule, если higher applicable.

### 10.7 `otherwise`

Для:

```mdl
rule O r when a: b otherwise c
```

solver добавляет fallback constraint:

```text
not a -> requirement(c)
```

Для `F` modality `requirement(c)` означает `not c`.

---

## 11. Темпоральная логика конечной трассы

Solver работает на конечной трассе длины `horizon`.

| MDL | Core | Смысл at time `t` |
|---|---|---|
| `p always` | `G` | `p` true на всех шагах `t..horizon-1` |
| `p eventually` | `F` | `p` true на некотором шаге `t..horizon-1` |
| `p next` | `X` | `p` true на `t+1`; false на последнем step |
| `p initially` | `initially` | `p` на step `0` |
| `p until q` | `U` | strong until: существует `u >= t`, где `q`, и `p` true на prefix до `u` |
| `last` | `last` | true только на `horizon - 1` |

Примеры:

```mdl
rule O pay: paid eventually
rule O always_compliant: compliant always
rule O until_receipt: waiting until receipt_sent
rule O final_check: last implies closed
```

### 11.1 Horizon options

```bash
mdl solve file.mdl --horizon 3
mdl solve file.mdl --max-horizon 5
```

Если задан `--horizon`, проверяется конкретный горизонт. Иначе solver перебирает горизонты от `1` до `max_horizon`.

---

## 12. Система типов

Type inference близок к Algorithm W: выводит типы, обобщает schemes, унифицирует, делает occurs check, проверяет records/tuples/functions/patterns.

### 12.1 Типы литералов

| Expression | Type |
|---|---|
| `true`, `false` | `bool` |
| `123` | `int` |
| `1/2` | `rat` |
| `1.2` | `decimal` |
| `"x"` | `string` |
| `()` | `unit` |
| `last` | `bool` в checker/solver context |

### 12.2 `if`

```mdl
if c then a else b
```

Rules:

- `c : bool`;
- branch types unify;
- result type = unified branch type.

### 12.3 `let`

```mdl
let p : T = v in body
```

Rules:

- if annotation exists, `v` must match `T`;
- pattern `p` binds names using value type;
- body checked in extended environment.

### 12.4 `case`

Rules:

- subject type inferred once;
- every arm pattern checked against subject type;
- guard, if present, must be bool;
- every arm body must unify to common result type.

### 12.5 Calls

Rules:

- callee must be callable function/constructor/scheme;
- arity must match;
- argument types unify with parameter types;
- generic schemes instantiated per call.

### 12.6 Records

Checker validates record constructors:

- duplicate fields;
- unknown fields;
- missing fields;
- field expression types.

Field access requires record-like type containing the field.

### 12.7 Operators

Boolean and temporal operators require `bool` operands.

Arithmetic operators require numeric operands.

Comparison operators return `bool`.

### 12.8 Facts and rules

Bare facts and rule bodies/antecedents are expected to be `bool`.

Targeted fact `fact x = expr` checks `expr` against type of `x`.

### 12.9 ADT constructors

Constructor patterns and constructor calls are checked against ADT variant declarations. Generic type parameters are instantiated and unified through constructor fields.

---

## 13. Runtime-семантика

### 13.1 Что исполняет runtime

Runtime evaluates:

- literals;
- names;
- calls;
- field access;
- unary/binary operations;
- `if`;
- `let`;
- `case`;
- record constructors;
- tuple literals;
- top-level values;
- functions;
- entities as environment slots;
- facts;
- selected stdlib/builtin collection constructors.

### 13.2 Что runtime не делает

Runtime не моделирует полноценную temporal/deontic semantics. Temporal unary в point-wise runtime возвращает operand point-wise; temporal binary `until` приводит к runtime error. Для temporal/deontic анализа используйте `solve`.

### 13.3 Evaluation order

Runtime:

1. регистрирует functions;
2. регистрирует entities with initial `None`;
3. вычисляет top-level values по порядку;
4. применяет facts;
5. возвращает values/facts или expression result для `run --expr`.

### 13.4 Runtime values

| MDL | Runtime representation |
|---|---|
| `int` | Python `int` |
| `decimal` | Python `float` |
| `rat` | Python `Fraction` |
| `string` | Python `str` |
| `bool` | Python `bool` |
| `unit` | Python `None` |
| tuple | Python `tuple` |
| record constructor | Python `dict` with fields |

### 13.5 Functions

User function call:

- checks arity;
- matches actual arguments against parameter patterns;
- extends environment;
- evaluates block;
- returns block result.

### 13.6 Pattern matching

Pattern mismatch in `let` or parameter binding raises runtime error. Non-exhaustive `case` raises runtime error.

### 13.7 Operators

Runtime implements:

```text
and or implies
== != < <= > >=
+ - * / %
not
unary -
```

`implies` is `(not left) or right`.

### 13.8 Collection constructor special cases

Runtime special-cases stdlib collection constructors:

```text
List.Empty()          -> []
List.Cons(head, tail) -> [head, *tail]

Set.Empty()           -> set()
Set.Insert(x, s)      -> copy of s with x inserted

Map.Empty()           -> {}
Map.Put(k, v, m)      -> copy/update dict

Option.None()         -> "None"
Option.Some(x)        -> ("Some", (x,))
```

Unknown ADT constructor fallback:

```text
(ConstructorName, tuple(args))
```

Это implementation detail; source-level MDL код должен мыслить ADT через constructors, а не через Python representation.

### 13.9 Builtin `to_list`

Runtime registers:

```text
to_list
strings.to_list
std.system.strings.to_list
```

as builtins mapping a string to host list of characters. Это отличается от source body `std.system.strings.to_list`, который в текущей stdlib возвращает `List.Empty()`.

---

## 14. Core translation / DDL-LTLf JSON

`translate` строит JSON-like core:

```json
{
  "language": "MDL-DDL-LTLf-Core",
  "version": "0.1",
  "module": "...",
  "annotations": [],
  "imports": [],
  "opens": [],
  "types": [],
  "values": [],
  "entities": [],
  "rules": [],
  "priorities": [],
  "facts": [],
  "atoms": []
}
```

Core сохраняет module, annotations, imports/opens, types, values, entities, rules, priorities, facts и lifted atoms.

### 14.1 Formula mapping

| MDL | Core |
|---|---|
| `true`, `false` | boolean literal |
| `last` | special `last` |
| `not p` | negation |
| `p and q` | conjunction |
| `p or q` | disjunction |
| `p implies q` | implication |
| `p always` | `G` |
| `p eventually` | `F` |
| `p next` | `X` |
| `p initially` | `initially` |
| `p until q` | `U` |

Function calls returning bool can be lifted to atoms with sanitized names; function bodies are not compiled as general-purpose pure code into core.

### 14.2 Rules in core

Rule core object includes name, strength, modality, antecedent, body, otherwise, annotations, anonymous flag and source span.

---

## 15. Standard library

Текущая stdlib находится в `mdl/src/mdl/stdlib/std`.

### 15.1 `std.collections`

```mdl
module std.collections
```

#### `List<T>`

```mdl
type List<T> = Empty(unit) | Cons(T, List<T>)
```

Constructors:

```mdl
List.Empty()
List.Cons(head, tail)
```

Runtime:

```text
List.Empty() -> []
List.Cons(x, xs) -> [x, *xs]
```

#### `Set<T>`

```mdl
type Set<T> = Empty(unit) | Insert(T, Set<T>)
```

Runtime:

```text
Set.Empty() -> set()
Set.Insert(x, s) -> copy of s with x
```

#### `Map<K, V>`

```mdl
type Map<K, V> = Empty(unit) | Put(K, V, Map<K, V>)
```

Runtime:

```text
Map.Empty() -> {}
Map.Put(k, v, m) -> copy/update dict
```

#### `Option<T>`

```mdl
type Option<T> = None(unit) | Some(T)
```

Runtime special cases:

```text
Option.None() -> "None"
Option.Some(x) -> ("Some", (x,))
```

#### `len<T>`

```mdl
func len<T>(l: List<T>) -> int:
  case l:
    | List.Empty(): 0
    | List.Cons(head, tail): 1 + len(tail)
```

Usage:

```mdl
import "std/collections.mdl"
open std.collections

let xs = List.Cons(1, List.Cons(2, List.Empty()))
let n = len(xs)
```

### 15.2 `std.system.strings`

```mdl
module std.system.strings

func to_list(value: string) -> std.collections.List<string>:
  std.collections.List.Empty()
```

Runtime builtin names:

```text
to_list
strings.to_list
std.system.strings.to_list
```

map host string to host list of characters.

### 15.3 Importing stdlib

```mdl
import "std/collections.mdl"
open std.collections
```

or fully qualified:

```mdl
let xs = std.collections.List.Empty()
```

---

## 16. CLI

### 16.1 Global

```bash
mdl --version
mdl --stdlib <path> ...
```

### 16.2 `parse`

```bash
mdl parse file.mdl
```

Parses source and prints parse/AST output.

### 16.3 `format`

```bash
mdl format file.mdl
mdl format file.mdl -o formatted.mdl
```

Pretty-prints source.

### 16.4 `lint`

```bash
mdl lint file.mdl
mdl lint file.mdl --json
```

Runs semantic checker/type checker.

### 16.5 `translate`

```bash
mdl translate file.mdl
mdl translate file.mdl -o core.json
```

Builds DDL-LTLf core JSON.

### 16.6 `run`

```bash
mdl run file.mdl
mdl run file.mdl --expr "some_expression"
```

Runs point-wise runtime.

### 16.7 `solve`

```bash
mdl solve file.mdl
mdl solve file.mdl --horizon 3
mdl solve file.mdl --max-horizon 5
mdl solve file.mdl --permission strong
mdl solve file.mdl --permission ignore
mdl solve file.mdl --max-conflicts 20
```

Solves one or more modules with finite horizon.

### 16.8 `align`

```bash
mdl align a.mdl b.mdl
mdl align a.mdl b.mdl --matcher auto
mdl align a.mdl b.mdl --matcher builtin
mdl align a.mdl b.mdl --matcher bdikit:coma
mdl align a.mdl b.mdl --candidate-threshold 0.4 --accept-threshold 0.8
mdl align a.mdl b.mdl --module-name align.generated -o align.mdl --report report.json --json
```

Aligner is tooling, not a grammar construct.

### 16.9 `lsp`

```bash
mdl lsp
```

Starts LSP server.

---

## 17. Грамматическая шпаргалка

Это compact EBNF по `MDL.g4`, не дословная копия файла.

### 17.1 Program

```ebnf
program      ::= newlines? annotations moduleDecl newlines? topItem* EOF
exprOnly     ::= expr EOF
typeExprOnly ::= typeExpr EOF

topItem ::= annotations (importDecl | openDecl | declaration) newlines?

annotations ::= ANNOT*
```

### 17.2 Modules/imports/open

```ebnf
moduleDecl ::= "module" qualifiedName
importDecl ::= "import" STRING
openDecl   ::= "open" qualifiedName
```

### 17.3 Declarations

```ebnf
declaration ::= typeDecl
              | valueDecl
              | funcDecl
              | entityDecl
              | ruleDecl
              | priorityDecl
              | factDecl
```

### 17.4 Types

```ebnf
typeDecl       ::= "type" nameToken typeParams? "=" typeDefinition
typeDefinition ::= recordType | variant ("|" variant)*

typeParams ::= "<" nameList ">"
typeArgs   ::= "<" typeExprList? ">"

variant          ::= nameToken "(" variantFieldList ")"
variantFieldList ::= variantField ("," variantField)* ","?
variantField     ::= nameToken ":" typeExpr | typeExpr

typeExpr ::= recordType | tupleOrParenType | typeRef

recordType    ::= "{" typeFieldList? "}"
typeFieldList ::= typeField ("," typeField)* ","?
typeField     ::= nameToken ":" typeExpr

tupleOrParenType ::= "(" typeExpr ")"
                   | "(" typeExpr "," typeExpr ("," typeExpr)* ","? ")"

typeRef      ::= qualifiedName typeArgs?
typeExprList ::= typeExpr ("," typeExpr)* ","?
```

### 17.5 Values/functions/entities

```ebnf
valueDecl ::= "let" nameToken typeAnnotation? "=" expr

funcDecl ::= "func" nameToken typeParams?
             "(" paramList? ")" "->" typeExpr ":" block

paramList ::= param ("," param)* ","?
param     ::= pattern ":" typeExpr

entityDecl ::= "entity" nameToken ":" typeExpr
```

### 17.6 Rules/priorities/facts

```ebnf
ruleDecl ::= ruleStrength? "rule" ruleBody ("otherwise" expr)?

ruleStrength ::= "strict" | "defeasible" | "defeater"

ruleBody ::= deonticMod ":" expr
           | deonticMod? qualifiedName ("when" expr)? ":" expr

deonticMod ::= "O" | "P" | "F"

priorityDecl ::= "override" qualifiedName (">" qualifiedName)*

factDecl ::= "fact" (nameToken "=")? expr
```

### 17.7 Blocks

```ebnf
block ::= NEWLINE INDENT blockLetStmt* expr? newlines? DEDENT
        | expr

blockLetStmt ::= "let" pattern typeAnnotation? "=" expr newlines

typeAnnotation ::= ":" typeExpr
```

### 17.8 Expressions

```ebnf
expr ::= temporalPostfix

temporalPostfix ::= implication temporalUnaryOp*

implication ::= orExpr ("implies" implication)?

orExpr  ::= andExpr ("or" andExpr)*
andExpr ::= temporalBinary ("and" temporalBinary)*

temporalBinary ::= comparison ("until" comparison)*

comparison ::= additive (("==" | "!=" | "<" | "<=" | ">" | ">=") additive)*

additive       ::= multiplicative (("+" | "-") multiplicative)*
multiplicative ::= unary (("*" | "/" | "%") unary)*

unary ::= ifExpr
        | letExpr
        | matchExpr
        | ("not" | "-") unary
        | postfix

ifExpr  ::= "if" expr "then" expr "else" expr
letExpr ::= "let" pattern typeAnnotation? "=" expr "in" expr

matchExpr ::= "case" expr ":" caseBody
caseBody  ::= newlines? caseArm+
caseArm   ::= "|" pattern ("when" expr)? ":" block newlines?

postfix       ::= primary postfixSuffix*
postfixSuffix ::= recordConstructorFields
                | "(" exprList? ")"
                | "." nameToken

recordConstructorFields ::= "{" recordConstructorFieldList? "}"
recordConstructorFieldList ::= recordConstructorField ("," recordConstructorField)* ","?
recordConstructorField ::= nameToken "=" expr

primary ::= STRING
          | INT
          | DECIMAL
          | RAT
          | "true"
          | "false"
          | "last"
          | qualifiedName
          | "(" ")"
          | "(" expr ")"
          | "(" expr "," expr ("," expr)* ","? ")"

exprList ::= expr ("," expr)* ","?

temporalUnaryOp ::= "always" | "eventually" | "next" | "initially"
```

### 17.9 Patterns

```ebnf
pattern ::= "_"
          | STRING
          | INT
          | DECIMAL
          | RAT
          | "(" ")"
          | "(" pattern ")"
          | "(" pattern "," pattern ("," pattern)* ","? ")"
          | "{" recordPatternFieldList? "}"
          | qualifiedName ("(" patternList? ")")?

patternList ::= pattern ("," pattern)* ","?

recordPatternFieldList ::= recordPatternField ("," recordPatternField)* ","?
recordPatternField     ::= nameToken ("=" pattern)?
```

### 17.10 Names/tokens

```ebnf
qualifiedName ::= nameToken ("." nameToken)*

nameToken ::= IDENT
            | "true"
            | "false"
            | "last"
            | "O"
            | "P"
            | "F"

nameList ::= nameToken ("," nameToken)* ","?
```

---

## 18. Примеры

### 18.1 Minimal module

```mdl
module demo.min

let x = 1
let y = x + 2
```

### 18.2 ADT and pattern matching

```mdl
module demo.option

type Option<T> = None(unit) | Some(T)

func default_int(value: Option<int>, fallback: int) -> int:
  case value:
    | Option.Some(x): x
    | Option.None(): fallback
```

### 18.3 Records

```mdl
module demo.records

type Person = Person({ name: string, age: int })

let ada = Person { name = "Ada", age = 42 }

func is_adult(p: { name: string, age: int }) -> bool:
  p.age >= 18
```

### 18.4 Lists

```mdl
module demo.lists

import "std/collections.mdl"
open std.collections

let xs = List.Cons(1, List.Cons(2, List.Empty()))
let n = len(xs)
```

### 18.5 Case guards

```mdl
module demo.abs

func abs(x: int) -> int:
  case x:
    | n when n < 0: -n
    | n: n
```

### 18.6 Obligation

```mdl
module demo.rules

entity invoice_issued: bool
entity paid: bool

fact invoice_issued = true

rule O pay_when_invoice when invoice_issued: paid eventually
```

### 18.7 Prohibition

```mdl
module demo.prohibition

entity confidential_disclosed: bool

rule F no_disclosure: confidential_disclosed
```

`F confidential_disclosed` requires `not confidential_disclosed`.

### 18.8 Override

```mdl
module demo.override

entity invoice_issued: bool
entity force_majeure: bool
entity paid: bool

fact invoice_issued = true
fact force_majeure = true

rule O normally_pay when invoice_issued: paid eventually
rule F no_payment_under_force_majeure when force_majeure: paid

override no_payment_under_force_majeure > normally_pay
```

### 18.9 Otherwise

```mdl
module demo.otherwise

entity invoice_issued: bool
entity paid: bool
entity reviewed: bool

rule O pay_or_review when invoice_issued: paid eventually otherwise reviewed
```

### 18.10 Temporal precedence

```mdl
module demo.precedence

entity p: bool
entity q: bool

# Разбирается как (p implies q) eventually
rule O r1: p implies q eventually

# Явно: если p, то когда-нибудь q
rule O r2: p implies (q eventually)
```

---

## 19. Особенности и ограничения реализации

1. `run` не является temporal/deontic interpreter. Для temporal semantics используйте `solve`.
2. `a < b < c` не имеет Python-like semantics; пишите `(a < b) and (b < c)`.
3. String escapes сохраняются с backslash, а не декодируются в управляющие символы.
4. В grammar нет list literal syntax; используйте `List.Empty()` и `List.Cons(...)`.
5. Нет lambda, циклов, mutable assignment.
6. Self-recursion functions поддерживается; mutual recursion зависит от порядка деклараций.
7. `Option.None()` runtime representation — internal detail (`"None"` в текущей реализации).
8. Temporal postfix имеет низкий синтаксический приоритет; ставьте скобки вокруг temporal subformulas.
9. `P` permission зависит от solver option `--permission strong|ignore`.
10. `override r1 > r2 > r3` создаёт adjacent defeat pairs; добавляйте `override r1 > r3`, если нужна явная пара.
11. Anonymous rule names generated; не используйте их как stable API.
12. Source stdlib `std.system.strings.to_list` и runtime builtin `to_list` расходятся по behavior.

---

## 20. Карта исходников

Основные файлы:

- [`mdl/README.md`](https://github.com/bearpro/standard-contradictions/blob/master/mdl/README.md) — overview, examples, current status.
- [`mdl/src/mdl/grammar/MDL.g4`](https://github.com/bearpro/standard-contradictions/blob/master/mdl/src/mdl/grammar/MDL.g4) — ANTLR grammar.
- [`mdl/src/mdl/ast.py`](https://github.com/bearpro/standard-contradictions/blob/master/mdl/src/mdl/ast.py) — AST model.
- [`mdl/src/mdl/ast_builder.py`](https://github.com/bearpro/standard-contradictions/blob/master/mdl/src/mdl/ast_builder.py) — parse tree -> AST, operator associativity, anonymous rule names, string handling.
- [`mdl/src/mdl/linter.py`](https://github.com/bearpro/standard-contradictions/blob/master/mdl/src/mdl/linter.py) — semantic checking, imports/opens, name resolution.
- [`mdl/src/mdl/type_inference.py`](https://github.com/bearpro/standard-contradictions/blob/master/mdl/src/mdl/type_inference.py) — type inference/unification.
- [`mdl/src/mdl/runtime.py`](https://github.com/bearpro/standard-contradictions/blob/master/mdl/src/mdl/runtime.py) — point-wise runtime.
- [`mdl/src/mdl/core.py`](https://github.com/bearpro/standard-contradictions/blob/master/mdl/src/mdl/core.py) — core JSON translator.
- [`mdl/src/mdl/solver.py`](https://github.com/bearpro/standard-contradictions/blob/master/mdl/src/mdl/solver.py) — finite-horizon solver.
- [`mdl/src/mdl/cli.py`](https://github.com/bearpro/standard-contradictions/blob/master/mdl/src/mdl/cli.py) — CLI commands.
- [`mdl/src/mdl/stdlib/std/collections.mdl`](https://github.com/bearpro/standard-contradictions/blob/master/mdl/src/mdl/stdlib/std/collections.mdl) — `List`, `Set`, `Map`, `Option`, `len`.
- [`mdl/src/mdl/stdlib/std/system/strings.mdl`](https://github.com/bearpro/standard-contradictions/blob/master/mdl/src/mdl/stdlib/std/system/strings.mdl) — `to_list`.

---

## Appendix. Мини-cheatsheet

```mdl
@annotation text
module my.module

import "std/collections.mdl"
open std.collections

type Option<T> = None(unit) | Some(T)
type Person = Person({ name: string, age: int })

let value: int = 1

func f<T>(x: T) -> T:
  x

entity paid: bool

fact paid = false
fact value > 0

rule O must_pay when invoice_issued: paid eventually
strict rule F never_disclose: disclosed
defeater rule O exception when special_case: act

override exception > must_pay
```

Expression cheatsheet:

```mdl
if c then a else b
let x = v in body
case x:
  | Pattern(args) when guard: body
  | _: fallback

record.field
TypeName { field = value }
f(arg1, arg2)
(a, b)

not p
p and q
p or q
p implies q
p until q
p always
p eventually
p next
p initially
last
```

