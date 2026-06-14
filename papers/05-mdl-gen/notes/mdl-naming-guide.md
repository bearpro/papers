## Правила именования объектов модели и структурирования `entity`

Главная цель правил именования — сделать модель предсказуемой для другого автора
и для алгоритма выравнивания. Два модуля, написанные независимо, должны с
высокой вероятностью описывать одинаковые предметные сущности похожим образом:
похожими именами, похожими типами и похожей структурой данных.

Важно: выравнивание касается только сущностей, явно объявленных через `entity`.
Типы, функции, правила и вспомогательные значения сами по себе не являются
объектами выравнивания. Они помогают понять структуру `entity`, но публичной
точкой сопоставления между модулями остаётся именно объявление вида:

```mdl
entity scalpel: Scalpel
```

### 1. `entity` — это публичный объект модели

Каждая `entity` должна обозначать предметную сущность, которая описывается в
исходном тексте стандарта, спецификации или требования.

Хорошо:

```mdl
entity scalpel: Scalpel
entity surgical_needle: SurgicalNeedle
entity sterile_package: SterilePackage
```

Плохо:

```mdl
entity requirement_1: Requirement
entity paragraph_4_2: Paragraph
entity thing: Object
entity data: Data
```

`entity` не должна называться по номеру требования, пункту документа,
внутреннему идентификатору, месту в тексте или технической роли в модели. Номера
пунктов могут использоваться в комментариях или именах правил, но не как имя
основной сущности.

### 2. Одна `entity` должна соответствовать одному устойчивому предметному понятию

Если в тексте описывается объект предметной области, его нужно моделировать как
`entity`. Если описывается свойство, состояние, ограничение или проверка, это
обычно поле типа или правило, но не отдельная `entity`.

Хорошо:

```mdl
entity scalpel: Scalpel

type Scalpel = {
    blade_material: Material,
    is_sterile: bool,
    package: SterilePackage
}
```

Плохо:

```mdl
entity scalpel_sterility: Sterility
entity scalpel_blade_material: Material
entity scalpel_package_state: PackageState
```

Исключение: свойство можно выносить в отдельную `entity`, если оно само является
независимой предметной сущностью в стандарте. Например, упаковка, сертификат,
пользователь, партия товара, процедура стерилизации или измерительный прибор
могут быть отдельными `entity`, если к ним предъявляются собственные требования.

### 3. Не создавать `entity` для каждого требования

`entity` описывает объект, а `rule` описывает требование к объекту. Требования
из текста должны группироваться вокруг тех `entity`, к которым они относятся.

Хорошо:

```mdl
entity surgical_instrument: SurgicalInstrument

rule O must_be_sterile:
    surgical_instrument.is_sterile == true always

rule O must_have_smooth_surface:
    surgical_instrument.surface_is_smooth == true always
```

Плохо:

```mdl
entity must_be_sterile: Requirement
entity must_have_smooth_surface: Requirement
```

Модель, где каждое требование превращается в отдельную `entity`, плохо
выравнивается с другими модулями: разные авторы почти всегда по-разному разобьют
текст на требования, но с большей вероятностью одинаково выделят предметные
объекты.

### 4. Имя `entity` должно быть существительным или именной группой

Имя `entity` должно отвечать на вопрос «что это?», а не «что оно делает?» или
«какое правило к нему применяется?».

Хорошо:

```mdl
entity pressure_sensor: PressureSensor
entity access_control_system: AccessControlSystem
entity emergency_stop_button: EmergencyStopButton
```

Плохо:

```mdl
entity measures_pressure: PressureSensor
entity controls_access: AccessControlSystem
entity must_stop_machine: EmergencyStopButton
```

Действия, обязанности и ограничения должны выражаться в правилах:

```mdl
rule O emergency_stop_button_stops_machine:
    emergency_stop_button.stops_machine == true always
```

### 5. Использовать единственное число

Имя `entity` должно быть в единственном числе, если оно обозначает один типовой
объект или один логический объект модели.

Хорошо:

```mdl
entity pipe: Pipe
entity user: User
entity surgical_instrument: SurgicalInstrument
```

Плохо:

```mdl
entity pipes: Pipe
entity users: User
entity surgical_instruments: SurgicalInstrument
```

Множественное число стоит использовать только тогда, когда сама сущность
является коллекцией как предметным объектом: например, `instrument_set`,
`user_group`, `batch`, `catalog`, `collection`.

```mdl
entity instrument_set: InstrumentSet
entity product_batch: ProductBatch
```

### 6. Имя `entity` должно быть стабильным, а не контекстным

Не нужно включать в имя `entity` сведения, которые зависят от конкретного
документа, раздела, версии стандарта, автора модели или способа проверки.

Плохо:

```mdl
entity iso_7153_scalpel: Scalpel
entity chapter_5_scalpel: Scalpel
entity current_standard_scalpel: Scalpel
entity checked_scalpel: Scalpel
```

Хорошо:

```mdl
entity scalpel: Scalpel
```

Если источник важен, его лучше отражать на уровне имени модуля, комментария или
имени правила, а не в имени `entity`.

```mdl
module ISO7153.SurgicalInstruments

entity scalpel: Scalpel
```

### 7. Не дублировать контекст модуля в имени `entity`

Если модуль уже задаёт область предметной модели, имя `entity` не должно
повторять этот контекст без необходимости.

Плохо:

```mdl
module MedicalDevices.SurgicalInstruments

entity medical_device_surgical_instrument_scalpel: Scalpel
entity surgical_instrument_scalpel: Scalpel
```

Хорошо:

```mdl
module MedicalDevices.SurgicalInstruments

entity scalpel: Scalpel
```

Но если без уточнения имя становится неоднозначным, контекст нужно оставить:

```mdl
entity surgical_needle: SurgicalNeedle
entity injection_needle: InjectionNeedle
```

### 8. Использовать единый стиль записи имён

Рекомендуемый стиль:

```mdl
entity surgical_instrument: SurgicalInstrument
type SurgicalInstrument = {
    surface_roughness: rat,
    is_sterile: bool
}
rule O surgical_instrument_must_be_sterile:
    surgical_instrument.is_sterile == true always
```

Правила стиля:

- `entity`: `lower_snake_case`;
- поля записей: `lower_snake_case`;
- функции: `lower_snake_case`;
- правила: `lower_snake_case`;
- типы: `PascalCase`;
- варианты sum-type: `PascalCase`.

Такой стиль помогает визуально отличать объявленную сущность от её типа:

```mdl
entity sterile_package: SterilePackage
```

Здесь `sterile_package` — конкретная сущность модели, а `SterilePackage` — тип
данных, описывающий её структуру.

### 9. Имя типа должно описывать класс объекта, имя `entity` — конкретную сущность модели

Обычно имя `entity` является `lower_snake_case`-версией имени типа:

```mdl
entity scalpel: Scalpel
entity sterile_package: SterilePackage
entity pressure_sensor: PressureSensor
```

Это самый предсказуемый вариант.

Если в одном модуле есть несколько сущностей одного типа, имя `entity` должно
уточнять роль или положение в предметной области:

```mdl
entity inlet_pipe: Pipe
entity outlet_pipe: Pipe
entity primary_pressure_sensor: PressureSensor
entity backup_pressure_sensor: PressureSensor
```

Плохо:

```mdl
entity pipe1: Pipe
entity pipe2: Pipe
entity sensor_a: PressureSensor
entity sensor_b: PressureSensor
```

Числа и буквы допустимы только если они являются частью официального предметного
обозначения, а не способом избежать выбора нормального имени.

### 10. Не использовать слишком общие имена

Слишком общие имена ухудшают выравнивание, потому что разные авторы могут
использовать их для разных понятий.

Плохо:

```mdl
entity item: Item
entity object: Object
entity component: Component
entity system: System
entity element: Element
```

Лучше:

```mdl
entity surgical_instrument: SurgicalInstrument
entity cutting_edge: CuttingEdge
entity access_control_system: AccessControlSystem
entity pressure_sensor: PressureSensor
```

Общее имя допустимо только если стандарт действительно говорит о таком общем
классе объектов и не вводит более точного термина.

### 11. Не использовать локальные сокращения

Сокращения снижают вероятность совпадения между модулями. Разные авторы могут
сократить одно и то же понятие по-разному.

Плохо:

```mdl
entity surg_instr: SurgicalInstrument
entity press_sens: PressureSensor
entity cert_doc: CertificateDocument
```

Хорошо:

```mdl
entity surgical_instrument: SurgicalInstrument
entity pressure_sensor: PressureSensor
entity certificate_document: CertificateDocument
```

Допустимы только общеупотребимые доменные сокращения, если они устойчивее полной
формы: например, `url`, `id`, `gps`, `http`, если эти термины действительно
используются в исходном тексте.

### 12. Не смешивать языки в именах

В рамках одного модуля нужно выбрать один язык имён и последовательно
использовать его. Для технических моделей обычно предпочтительнее английский,
потому что он чаще совпадает между независимыми авторами и лучше переносится
между стандартами.

Хорошо:

```mdl
entity surgical_instrument: SurgicalInstrument
entity sterile_package: SterilePackage
```

Плохо:

```mdl
entity surgical_instrument: SurgicalInstrument
entity sterilnaya_upakovka: SterilePackage
entity hirurgicheskiy_instrument: SurgicalInstrument
```

Если исходный стандарт использует термин на другом языке, можно добавить
комментарий:

```mdl
# Source term: "стерильная упаковка"
entity sterile_package: SterilePackage
```

### 13. Сохранять терминологию исходного текста, но нормализовать форму

Имя должно быть близко к термину из стандарта, но приведено к стабильной форме:
единственное число, без артиклей, без лишних прилагательных, без грамматических
вариантов.

Исходный текст:

> The surgical instruments shall be sterile.

Хорошо:

```mdl
entity surgical_instrument: SurgicalInstrument
```

Плохо:

```mdl
entity the_surgical_instruments: SurgicalInstrument
entity instruments_described_above: SurgicalInstrument
entity sterile_surgical_instrument: SurgicalInstrument
```

Прилагательное нужно оставлять в имени только если оно различает разные
предметные сущности, а не просто повторяет требование. Например,
`sterile_package` хорошо, если это термин предметной области. Но
`sterile_scalpel` плохо, если стерильность является требованием к `scalpel`.

### 14. Не включать значения свойств в имя `entity`

Если значение может изменяться или проверяется правилом, оно должно быть полем,
а не частью имени.

Плохо:

```mdl
entity sterile_scalpel: Scalpel
entity red_warning_light: WarningLight
entity approved_user: User
entity active_certificate: Certificate
```

Лучше:

```mdl
entity scalpel: Scalpel
entity warning_light: WarningLight
entity user: User
entity certificate: Certificate
```

```mdl
type Scalpel = {
    is_sterile: bool
}

type WarningLight = {
    color: Color
}

type User = {
    is_approved: bool
}

type Certificate = {
    is_active: bool
}
```

Исключение: значение можно оставить в имени, если оно является частью
устойчивого термина, а не проверяемым состоянием. Например,
`emergency_stop_button` — это нормальное имя, потому что «emergency stop»
обозначает тип кнопки, а не текущее состояние кнопки.

### 15. Структура `entity` должна отражать предметную структуру, а не структуру текста

Поля типа должны описывать свойства объекта, его части, связи с другими
объектами и состояния, а не номера пунктов документа.

Плохо:

```mdl
type Scalpel = {
    clause_4_1: bool,
    clause_4_2: bool,
    paragraph_a: string
}
```

Хорошо:

```mdl
type Scalpel = {
    blade_material: Material,
    handle_material: Material,
    is_sterile: bool,
    has_smooth_surface: bool
}
```

Если нужно сохранить связь с исходным пунктом, её лучше писать в комментарии
рядом с правилом:

```mdl
# ISO 0000, clause 4.2
rule O scalpel_surface_must_be_smooth:
    scalpel.has_smooth_surface == true always
```

### 16. Выносить независимые предметные объекты в отдельные `entity`

Если объект имеет собственные требования, собственный жизненный цикл или может
сопоставляться с объектами из других стандартов, его нужно объявлять как
отдельную `entity`.

Хорошо:

```mdl
entity scalpel: Scalpel
entity sterile_package: SterilePackage

type Scalpel = {
    package: SterilePackage
}
```

Плохо:

```mdl
entity scalpel: Scalpel

type Scalpel = {
    package_is_sterile: bool,
    package_label: string,
    package_integrity_is_preserved: bool
}
```

В плохом варианте упаковка спрятана внутри `scalpel`, хотя другой модуль может
описывать упаковку как самостоятельную сущность. Это ухудшит выравнивание.

### 17. Не выносить каждое поле в отдельную `entity`

Обратная ошибка — делать отдельную сущность из всего, что имеет имя.

Плохо:

```mdl
entity blade_length: Length
entity blade_material: Material
entity handle_material: Material
entity scalpel_sterility: Sterility
```

Хорошо:

```mdl
entity scalpel: Scalpel

type Scalpel = {
    blade_length: rat,
    blade_material: Material,
    handle_material: Material,
    is_sterile: bool
}
```

Отдельная `entity` нужна только тогда, когда это самостоятельный объект
предметной области, а не простое свойство.

### 18. Использовать композицию для частей объекта

Если сущность состоит из частей, части лучше отражать в типе как поля с
осмысленными именами.

```mdl
entity scalpel: Scalpel

type Scalpel = {
    blade: Blade,
    handle: Handle
}

type Blade = {
    material: Material,
    length: rat
}

type Handle = {
    material: Material,
    is_slip_resistant: bool
}
```

Если часть объекта сама регулируется отдельными правилами и может выравниваться
с другими модулями, её можно объявить как отдельную `entity`:

```mdl
entity scalpel_blade: Blade
entity scalpel_handle: Handle
```

Но это нужно делать только при наличии самостоятельных требований к этим частям.

### 19. Связи между сущностями выражать через поля

Если одна сущность ссылается на другую, связь должна быть видна в структуре
типа.

```mdl
entity user: User
entity access_card: AccessCard

type User = {
    card: AccessCard,
    is_authorized: bool
}
```

Плохо прятать связь в имени:

```mdl
entity user_with_access_card: User
```

Имя должно обозначать объект, а структура типа — его связи.

### 20. Не кодировать модальность требования в имени `entity`

Модальность — обязательность, разрешение, запрет — должна выражаться через
`rule O`, `rule P` или `rule F`, а не через имя сущности.

Плохо:

```mdl
entity mandatory_sterile_scalpel: Scalpel
entity forbidden_open_package: Package
entity permitted_user: User
```

Хорошо:

```mdl
entity scalpel: Scalpel
entity package: Package
entity user: User
```

```mdl
rule O scalpel_must_be_sterile:
    scalpel.is_sterile == true always
```

### 21. Имена правил должны ссылаться на `entity`, но не заменять её

Имя правила должно быть читаемым и показывать, к какой сущности относится
ограничение.

Хорошо:

```mdl
rule O scalpel_must_be_sterile:
    scalpel.is_sterile == true always

rule O package_must_remain_closed:
    sterile_package.is_closed == true always
```

Плохо:

```mdl
rule O rule_1:
    scalpel.is_sterile == true always

rule O sterility:
    scalpel.is_sterile == true always
```

Однако правило не участвует в выравнивании так же, как `entity`. Поэтому имя
правила должно быть удобным для чтения и отладки, но критически важно прежде
всего корректно назвать саму `entity`.

### 22. Имена полей должны быть предметными и локальными к типу

Поле не должно повторять имя типа, если это не нужно для ясности.

Плохо:

```mdl
type Scalpel = {
    scalpel_blade_material: Material,
    scalpel_is_sterile: bool
}
```

Хорошо:

```mdl
type Scalpel = {
    blade_material: Material,
    is_sterile: bool
}
```

Внутри `Scalpel` уже понятно, что поля относятся к скальпелю.

### 23. Для булевых полей использовать форму предиката

Булевые поля должны читаться как утверждения.

Хорошо:

```mdl
type Package = {
    is_sterile: bool,
    is_closed: bool,
    has_label: bool,
    contains_instructions: bool
}
```

Плохо:

```mdl
type Package = {
    sterile: bool,
    closed: bool,
    label: bool,
    instructions: bool
}
```

Имена `is_*`, `has_*`, `contains_*`, `allows_*`, `requires_*` делают правила
читаемыми:

```mdl
rule O package_must_have_label:
    sterile_package.has_label == true always
```

### 24. Для числовых полей указывать измеряемую величину, а не единицу

Имя поля должно обозначать, что измеряется. Единицы измерения должны задаваться
типом, соглашением модели или отдельной структурой, а не только именем поля.

Хорошо:

```mdl
type Pipe = {
    length: rat,
    radius: rat
}
```

Допустимо, если в MDL-модели пока нет отдельной системы единиц:

```mdl
type Pipe = {
    length_mm: rat,
    radius_mm: rat
}
```

Но хуже использовать только единицу или неоднозначное имя:

```mdl
type Pipe = {
    mm: rat,
    size: rat,
    value: rat
}
```

### 25. При конфликте между краткостью и ясностью выбирать ясность

Имя должно быть достаточно коротким, чтобы не мешать читать правила, но
достаточно полным, чтобы другой автор понял тот же объект.

Хорошо:

```mdl
entity emergency_stop_button: EmergencyStopButton
```

Плохо:

```mdl
entity esb: EmergencyStopButton
entity button: EmergencyStopButton
entity emergency_stop_button_used_to_stop_machine_in_case_of_danger: EmergencyStopButton
```

Оптимальное имя обычно состоит из 1–4 значимых слов.

### 26. Использовать уточнения только для различения сущностей

Уточняющие слова нужны, когда без них разные объекты становятся неразличимыми.

Хорошо:

```mdl
entity inlet_valve: Valve
entity outlet_valve: Valve
entity manual_override_switch: Switch
entity emergency_stop_switch: Switch
```

Плохо:

```mdl
entity valve: Valve
entity valve_2: Valve
entity switch: Switch
entity switch_for_system: Switch
```

Уточнение должно быть предметным: `inlet`, `outlet`, `primary`, `backup`,
`manual`, `automatic`, `emergency`, `sterile`, `transport`, если эти слова
действительно различают классы или роли объектов в тексте.

### 27. Избегать отрицательных имён

Не стоит называть сущность через отсутствие свойства.

Плохо:

```mdl
entity non_sterile_scalpel: Scalpel
entity unapproved_user: User
entity invalid_certificate: Certificate
```

Хорошо:

```mdl
entity scalpel: Scalpel
entity user: User
entity certificate: Certificate
```

```mdl
type Scalpel = {
    is_sterile: bool
}

type User = {
    is_approved: bool
}

type Certificate = {
    is_valid: bool
}
```

Отрицание должно быть в правиле, если стандарт запрещает состояние:

```mdl
rule F certificate_is_invalid:
    certificate.is_valid == false eventually
```

### 28. Не использовать имена, зависящие от реализации модели

Имя `entity` не должно описывать, как автор решил технически представить данные.

Плохо:

```mdl
entity scalpel_record: Scalpel
entity user_state_machine: User
entity package_tuple: Package
entity instrument_data: SurgicalInstrument
```

Хорошо:

```mdl
entity scalpel: Scalpel
entity user: User
entity package: Package
entity surgical_instrument: SurgicalInstrument
```

MDL-модель описывает требования к предметной области, а не структуру базы
данных, JSON-схему или внутреннее представление.

### 29. Разделять родовое понятие и специализированное понятие

Если стандарт вводит и общий класс, и частные виды объектов, их нужно
моделировать явно.

```mdl
entity surgical_instrument: SurgicalInstrument
entity scalpel: Scalpel
entity forceps: Forceps
```

Типы можно связать через поля или через более конкретные структуры, в
зависимости от возможностей языка и принятого стиля модели:

```mdl
type SurgicalInstrument = {
    is_sterile: bool,
    has_smooth_surface: bool
}

type Scalpel = {
    instrument: SurgicalInstrument,
    blade_material: Material
}
```

Не стоит заменять всё одним слишком общим объектом, если в тексте есть
требования к конкретным видам:

```mdl
entity instrument: Instrument
```

И не стоит создавать только частные объекты, если требования явно относятся к
общему классу.

### 30. Общие требования лучше привязывать к общей `entity`

Если требование относится ко всем хирургическим инструментам, оно должно быть
записано через общую сущность:

```mdl
entity surgical_instrument: SurgicalInstrument

rule O surgical_instrument_must_be_sterile:
    surgical_instrument.is_sterile == true always
```

Если требование относится только к скальпелю, оно должно быть записано через
`scalpel`:

```mdl
entity scalpel: Scalpel

rule O scalpel_blade_must_be_protected:
    scalpel.blade_is_protected == true always
```

Так модель лучше выравнивается с другими моделями, где общие и частные
требования могут быть разнесены по разным модулям.

### 31. Предпочитать явные структуры неявным строкам

Если поле имеет ограниченный набор значений или внутреннюю структуру, лучше
создать отдельный тип, а не использовать `string`.

Плохо:

```mdl
type Package = {
    status: string,
    material: string
}
```

Лучше:

```mdl
type Package = {
    status: PackageStatus,
    material: Material
}

type PackageStatus =
    Opened
    | Closed
    | Damaged
```

Строки стоит использовать для действительно свободного текста: имени, описания,
маркировки, идентификатора, если его структура не важна для требований.

### 32. Не прятать несколько сущностей в одном поле

Если поле фактически содержит несколько разных предметных объектов, структуру
нужно раскрыть.

Плохо:

```mdl
type SurgicalKit = {
    contents: string
}
```

Лучше:

```mdl
type SurgicalKit = {
    scalpel: Scalpel,
    forceps: Forceps,
    sterile_package: SterilePackage
}
```

Если количество объектов переменное, можно использовать коллекцию, но только
когда это действительно нужно для требований. В текущем гайде уже отмечено, что
коллекции и рекурсии лучше использовать осторожно, потому что они тяжело
вычисляются.

### 33. Не создавать искусственную «главную» `entity`, если в тексте её нет

Иногда авторы пытаются завернуть всю модель в одну сущность:

```mdl
entity standard_model: StandardModel
entity system: System
entity document: Document
```

Так делать не нужно, если исходный текст не предъявляет требований к самому
документу, системе в целом или модели как объекту. Лучше объявить реальные
предметные сущности:

```mdl
entity scalpel: Scalpel
entity sterile_package: SterilePackage
entity surgical_kit: SurgicalKit
```

Искусственная верхнеуровневая сущность ухудшает выравнивание, потому что другой
автор может вообще её не создать.

### 34. Если сущность есть в другом стандарте, выбирать наиболее общепринятое имя

При выборе между синонимами нужно предпочитать термин, который с большей
вероятностью встретится в других стандартах и моделях.

Например, если встречаются варианты `physician`, `doctor`,
`medical_practitioner`, нужно выбрать наиболее доменно точный термин для данной
модели и последовательно использовать его. Если стандарт сам вводит определение
термина, нужно следовать стандарту.

Допустимо оставить синоним в комментарии:

```mdl
# Also referred to as "doctor" in some sources.
entity medical_practitioner: MedicalPractitioner
```

Не нужно создавать несколько `entity` для синонимов одного объекта:

```mdl
entity doctor: MedicalPractitioner
entity physician: MedicalPractitioner
entity medical_practitioner: MedicalPractitioner
```

Если это один и тот же объект, он должен быть объявлен один раз.

### 35. Не использовать одинаковые имена для разных смыслов

Один термин в модуле должен означать одно понятие. Если слово неоднозначно, его
нужно уточнить.

Плохо:

```mdl
entity operator: Person
entity operator: Function
```

Лучше:

```mdl
entity machine_operator: Person
entity arithmetic_operator: Operator
```

Даже если язык не позволит объявить два одинаковых имени, это правило важно для
полей, типов и правил: одинаковые или почти одинаковые имена не должны
обозначать разные предметные понятия.

### 36. Согласовывать имя `entity`, имя типа и поля, которые на неё ссылаются

Если сущность называется `sterile_package`, то поля-ссылки на неё должны
называться предсказуемо:

```mdl
entity sterile_package: SterilePackage

type Scalpel = {
    package: SterilePackage
}
```

или, если в типе есть несколько упаковок:

```mdl
type Product = {
    primary_package: SterilePackage,
    transport_package: TransportPackage
}
```

Плохо:

```mdl
entity sterile_package: SterilePackage

type Scalpel = {
    container: SterilePackage
}
```

`container` может быть корректным доменным термином, но если это та же упаковка,
лучше использовать тот же словарь.

### 37. Поля должны группировать свойства вокруг естественного владельца

Свойство должно находиться в том типе, которому оно предметно принадлежит.

Плохо:

```mdl
type Scalpel = {
    package_is_closed: bool,
    package_label_is_readable: bool
}
```

Лучше:

```mdl
type Scalpel = {
    package: SterilePackage
}

type SterilePackage = {
    is_closed: bool,
    label_is_readable: bool
}
```

Если свойство относится к упаковке, оно должно быть внутри `SterilePackage`, а
не внутри `Scalpel`.

### 38. Не смешивать состояние объекта и событие

Состояние объекта моделируется полем, событие — отдельным типом или правилом,
если оно действительно нужно.

Хорошо:

```mdl
type Package = {
    is_open: bool
}
```

Если стандарт говорит о событии вскрытия:

```mdl
type PackageOpening = {
    package: Package,
    is_authorized: bool
}
```

Плохо:

```mdl
entity package_opened: Package
entity opening_happened_package: Package
```

События не нужно превращать в `entity`, если требования можно выразить через
состояние объекта и темпоральное выражение.

### 39. Проверять каждую новую `entity` тремя вопросами

Перед добавлением новой `entity` нужно ответить на три вопроса:

1. Описывает ли она самостоятельный предметный объект из исходного текста?
2. Мог бы другой стандарт предъявлять требования к этому же объекту?
3. Будет ли полезно выравнивать этот объект с объектом из другого модуля?

Если хотя бы на два вопроса ответ «нет», скорее всего, это не `entity`, а поле,
тип, вариант типа или правило.

### 40. Минимальный шаблон хорошей сущности

Хорошая `entity` обычно выглядит так:

```mdl
entity emergency_stop_button: EmergencyStopButton

type EmergencyStopButton = {
    is_accessible: bool,
    is_visible: bool,
    stops_machine: bool
}

rule O emergency_stop_button_must_be_accessible:
    emergency_stop_button.is_accessible == true always

rule O emergency_stop_button_must_stop_machine:
    emergency_stop_button.stops_machine == true always
```

В этом примере:

- имя `entity` обозначает предметный объект;
- тип описывает структуру объекта;
- поля выражают свойства объекта;
- правила выражают требования;
- имя не зависит от номера пункта, документа, реализации или конкретного автора
  модели.

### 41. Признаки плохой `entity`

`entity` почти наверняка выбрана неправильно, если её имя:

- начинается с `requirement`, `rule`, `clause`, `paragraph`, `section`;
- содержит номер пункта документа;
- содержит модальность: `mandatory`, `forbidden`, `permitted`;
- содержит временное состояние: `active`, `invalid`, `opened`, `approved`, если
  это не устойчивый термин;
- является слишком общим: `object`, `item`, `data`, `thing`;
- является сокращением, понятным только автору;
- описывает проверку, а не объект;
- совпадает с именем свойства, а не самостоятельной сущности;
- содержит источник, версию стандарта или имя файла;
- нужна только для того, чтобы удобнее написать одно правило.

### 42. Итоговое правило

`entity` — это главный публичный якорь MDL-модели. Её имя должно быть таким,
чтобы другой автор, моделирующий тот же предмет по другому стандарту, с высокой
вероятностью выбрал то же или очень похожее имя.

Поэтому хорошее имя `entity` должно быть:

- предметным;
- устойчивым;
- единственным;
- достаточно точным;
- независимым от структуры документа;
- независимым от реализации модели;
- согласованным с именем типа и полями;
- пригодным для межмодульного выравнивания.
