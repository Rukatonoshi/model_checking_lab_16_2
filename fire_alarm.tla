------------------------------ MODULE fire_alarm -----------------------------
(*
  МОДЕЛЬ СИСТЕМЫ ПОЖАРНОЙ СИГНАЛИЗАЦИИ
  
  Основные компоненты:
  1. Датчики (дым, пламя, кнопка)
  2. Система звукового оповещения
  3. Система автоматического пожаротушения
  4. Ручное управление
  
  Логика работы:
  - При срабатывании любого датчика включается сигнализация и система пожаротушения
  - Система работает до: истечения таймера, опустошения бака или ручного отключения
  - Ручное отключение полностью сбрасывает состояние системы
*)

EXTENDS Integers, TLC  \* Подключаем модули для работы с числами и верификации

(*-- Системные константы --*)
CONSTANTS 
    MaxMixture,          \* Максимальный объем огнетушащей смеси в баке (например, 100 ед.)
    ConsumptionRate,     \* Расход смеси за один такт работы (например, 3 ед./такт)
    TimerDuration        \* Время непрерывной работы системы в тактах (например, 10 тактов)

(*-- Состояние системы --*)
VARIABLES
    smoke,              \* Датчик дыма: TRUE - обнаружен дым
    flame,              \* Датчик пламени: TRUE - обнаружено пламя
    panic_button,       \* Кнопка тревоги: TRUE - нажата
    manual_override,    \* Ручное отключение: TRUE - система заблокирована
    alarm_on,           \* Сигнализация: TRUE - активна
    fire_suppression_on,\* Пожаротушение: TRUE - активно
    suppression_timer,  \* Таймер работы системы (обратный отсчёт)
    mixture_level,       \* Текущий уровень смеси в баке
    manual_override_timer \* Таймер для ограничения времени ручного отключения

(*-- Инициализация системы --*)
Init == 
    /\ smoke = FALSE                \* Все датчики выключены
    /\ flame = FALSE
    /\ panic_button = FALSE
    /\ manual_override = FALSE     \* Ручное управление не активно
    /\ alarm_on = FALSE            \* Сигнализация выключена
    /\ fire_suppression_on = FALSE \* Система пожаротушения не работает
    /\ suppression_timer = 0       \* Таймер сброшен
    /\ mixture_level = MaxMixture  \* Бак полностью заполнен
    /\ manual_override_timer = 0   \* Таймер ручного управления сброшен

(*-- Обновление состояния датчиков --*)
(* Каждый датчик может случайным образом изменить состояние *)
UpdateSensors ==
    /\ smoke' \in {TRUE, FALSE}        \* Дым: случайное новое состояние
    /\ flame' \in {TRUE, FALSE}        \* Пламя: случайное новое состояние
    /\ panic_button' \in {TRUE, FALSE} \* Кнопка: случайное новое состояние
    /\ alarm_on' = (smoke' \/ flame' \/ panic_button') \* Сигнализация активируется, если любой датчик сработал

(*-- Логика таймера ручного управления --*)
(* Управляет временем удержания кнопки ручного отключения *)
ManualOverrideTimer ==
    IF manual_override 
    THEN 
        manual_override_timer' = 
            IF manual_override_timer > 0 
            THEN manual_override_timer - 1 
            ELSE 0
    ELSE 
        manual_override_timer' = 0

(*-- Переключение ручного режима --*)
(* Ручное управление можно включить только при активной сигнализации, 
   а выключить только после истечения таймера ручного режима *)
ManualOverrideSwitch ==
    manual_override' \in 
        IF manual_override = FALSE 
        THEN 
            IF alarm_on 
            THEN {FALSE, TRUE}  \* Разрешаем включить ручное управление, если сигнализация активна
            ELSE {FALSE}
        ELSE 
            IF manual_override_timer = 0 
            THEN {FALSE}  \* Разрешаем выключить ручное управление после истечения таймера
            ELSE {TRUE}   \* Запрещаем выключение ручного управления, пока таймер активен

(*-- Логика работы при ручном управлении --*)
(* При активации ручного режима:
   - Немедленно выключаем все системы
   - Сбрасываем таймер
   - Восстанавливаем уровень смеси до максимума *)
ManualOverrideLogic ==
    IF manual_override' = TRUE 
    THEN 
        /\ alarm_on' = FALSE 
        /\ fire_suppression_on' = FALSE 
        /\ suppression_timer' = 0 
        /\ mixture_level' = MaxMixture 
        /\ manual_override_timer' = 3  \* Таймер ручного управления: 3 такта удержания
    ELSE 
        /\ alarm_on' = (smoke' \/ flame' \/ panic_button') \* Сигнализация активируется при срабатывании датчиков
        /\ fire_suppression_on' = 
            IF (smoke' \/ flame' \/ panic_button') /\ (mixture_level > 0) 
            THEN TRUE  \* Пожаротушение активно при наличии триггера и смеси
            ELSE FALSE
        /\ mixture_level' = 
            IF fire_suppression_on' 
            THEN 
                IF mixture_level - ConsumptionRate >= 0 
                THEN mixture_level - ConsumptionRate  \* Уменьшаем уровень смеси
                ELSE 0  \* Защита от отрицательных значений
            ELSE mixture_level
        /\ suppression_timer' = 
            IF fire_suppression_on' /\ mixture_level' > 0 
            THEN TimerDuration  \* Устанавливаем таймер на полное время
            ELSE suppression_timer  \* Сохраняем текущее значение

(*-- Логика работы таймера --*)
(* Таймер системы пожаротушения уменьшается только при активной системе *)
TimerLogic ==
    IF fire_suppression_on 
    THEN 
        IF suppression_timer > 0 
        THEN suppression_timer' = suppression_timer - 1 
        ELSE suppression_timer' = 0 
    ELSE suppression_timer' = suppression_timer 

(*-- Переход между состояниями системы --*)
Next ==
    /\ UpdateSensors            \* Обновляем показания датчиков
    /\ ManualOverrideTimer      \* Обновляем таймер ручного управления
    /\ ManualOverrideSwitch     \* Проверяем возможность ручного управления
    /\ ManualOverrideLogic      \* Применяем логику ручного режима
    /\ TimerLogic               \* Обновляем состояние таймера

FAIRNESS ==
    /\ ~manual_override
    /\ smoke
    /\ flame
    /\ panic_button

(*----------------------------------------*)
(*           СВОЙСТВА СИСТЕМЫ            *)
(*----------------------------------------*)

(*-- Базовые свойства безопасности --*)

(* 1. Система не может работать при пустом баке *)
Property1 == 
    mixture_level = 0 => ~fire_suppression_on

(* 2. Сигнализация активируется при срабатывании датчиков *)
Property2 == 
    []((smoke \/ flame \/ panic_button) /\ ~manual_override => <>alarm_on)

(* 3. Система пожаротушения всегда завершает работу *)
Property3 == 
    [] (fire_suppression_on => <> (~fire_suppression_on))

(* 4. Корректность условий активации пожаротушения *)
Property4 == 
    fire_suppression_on => 
        ~manual_override                \* Нет ручного отключения
        /\ (smoke \/ flame \/ panic_button) \* Есть триггер
        /\ mixture_level > 0            \* Есть смесь
        /\ suppression_timer > 0        \* Таймер активен

(* 5. Система работает минимум один такт после активации *)
Property5 == 
    <> (fire_suppression_on => 
        (mixture_level = 0 \/ ~manual_override))

(* 6. Возможность повторной активации после остановки *)
Property6 == 
    [] ( (fire_suppression_on /\ (suppression_timer = 0 \/ mixture_level = 0 \/ manual_override))
        => <> (~fire_suppression_on /\ <> fire_suppression_on) )

(* 7. Таймер всегда неотрицательный *)
Property7 == 
    suppression_timer >= 0

(* 8. Запас смеси всегда неотрицательный *)
Property8 ==
    mixture_level >= 0 /\ mixture_level <= MaxMixture

(*-- Спецификация модели --*)
Spec == 
    Init /\ [][Next]_<<smoke, flame, panic_button, manual_override, 
                     alarm_on, fire_suppression_on, 
                     suppression_timer, mixture_level, manual_override_timer>>
=============================================================================
