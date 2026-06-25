/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Павлов Владимир Александрович
 * Дата: 19 июня 2025г.
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
-- Напишите ваш запрос здесь
 -- Общий запрос для всех игроков
  SELECT 
  COUNT(*) AS total_users,          -- Общее количество игроков
  SUM(payer) AS paying_users,       -- Количество платящих игроков
  ROUND(AVG(payer) * 100, 2) AS paying_percentage  -- Доля платящих в процентах
  FROM fantasy.users;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
-- Напишите ваш запрос здесь
 -- Запрос для анализа по расам
   SELECT 
   race,
   SUM(payer) AS paying_users, -- Количество платящих игроков по расе
   COUNT(*) AS total_users_by_race, -- Общее количество игроков по расе
   ROUND(SUM(payer)::decimal / COUNT(*) * 100, 2) AS paying_percentage_by_race -- Доля платящих по расе
   FROM fantasy.users AS u 
   LEFT JOIN fantasy.race AS r ON u.race_id=r.race_id
   GROUP BY race
   ORDER BY paying_percentage_by_race DESC;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
-- Напишите ваш запрос здесь
    SELECT 
    COUNT(*) AS total_transactions,          -- Общее количество транзакций
    SUM(amount) AS total_amount,             -- Общая сумма всех транзакций
    AVG(amount) AS avg_amount,               -- Средняя сумма транзакции
    MIN(amount) AS min_amount,               -- Минимальная сумма транзакции
    MAX(amount) AS max_amount,               -- Максимальная сумма транзакции
    STDDEV(amount) AS std_dev,               -- Стандартное отклонение сумм
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount) AS median,  -- Медиана
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY amount) AS p25,    -- 25-й процентиль
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY amount) AS p75     -- 75-й процентиль
   FROM fantasy.events
   WHERE amount > 0;

-- 2.2: Аномальные нулевые покупки:
-- Напишите ваш запрос здесь
-- CTE для определения пользователей с множественными нулевыми транзакциями
WITH transaction_summary AS (
    SELECT 
        -- Подсчет всех транзакций
        COUNT(*) AS total_transactions,
        
        -- Подсчет нулевых транзакций
        COUNT(*) FILTER (WHERE amount = 0) AS zero_transactions,
        
        -- Расчет доли нулевых транзакций в процентах
        ROUND(
            CAST(COUNT(*) FILTER (WHERE amount = 0) AS numeric) / 
            COUNT(*) * 100, 
            2
        ) AS zero_transaction_share
    
    FROM fantasy.events
)

-- Финальный запрос
SELECT 
    zero_transactions, -- Общее количество нулевых транзакций
    total_transactions, -- Общее количество всех транзакций
    zero_transaction_share -- Доля нулевых транзакций в процентах

FROM transaction_summary

-- Фильтруем только случаи с более одной нулевой транзакцией
WHERE zero_transactions > 1;

-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков

-- CTE для получения базовой информации о пользователях
WITH user_summary AS (
SELECT 
u.id,  --ID пользователя
u.payer,  -- Флаг платящего пользователя
COUNT(e.id) AS total_events,  -- Общее количество событий
SUM(e.amount) AS total_amount  -- Общая сумма транзакций
FROM fantasy.users AS u 
LEFT JOIN fantasy.events AS e ON u.id=e.id 
LEFT JOIN fantasy.items AS i ON e.item_code=i.item_code
WHERE e.amount > 0
GROUP BY u.id,u.payer 
),
-- CTE для агрегации данных по типам пользователей
aggregated_status AS  (
SELECT 
payer,  -- Флаг платящего пользователя
COUNT(DISTINCT id) AS total_payers, -- Общее количество пользователей
AVG(total_events) AS avg_purchases, -- Среднее количество покупок
AVG(total_amount) AS avg_amount_per_payer  -- Средняя сумма на пользователя
FROM user_summary 
GROUP BY payer 
)
-- Финальный запрос для форматирования результатов
SELECT DISTINCT
CASE WHEN payer=1 THEN 'платящий' ELSE 'неплатящий' END AS payer_type, -- Тип пользователя
ROUND(total_payers,2) AS total_payers,  -- Общее количество пользователей
ROUND(avg_purchases,2) AS avg_purchases,  -- Среднее количество покупок
ROUND(avg_amount_per_payer::integer,2) AS avg_amount_per_payer -- Средняя сумма на пользователя 
FROM aggregated_status;

-- 2.4: Популярные эпические предметы:
-- Напишите ваш запрос здесь
-- CTE для получения информации о предметах
WITH item_purchases AS (
    SELECT DISTINCT
        i.game_items,                 -- Название предмета
        COUNT(DISTINCT e.id) AS purchasers,  -- Количество уникальных покупателей
        COUNT(*) AS purchase_count,   -- Общее количество покупок
        SUM(e.amount) AS total_revenue,  -- Общая выручка от предмета
        
        -- Относительное количество покупок (в процентах от всех покупок)
        COUNT(*) * 100.0 / 
            (SELECT COUNT(*) FROM fantasy.events WHERE amount > 0) AS relative_purchase_count,
        
        -- Доля покупателей предмета от общего числа покупателей (в процентах)
        COUNT(DISTINCT e.id) * 100.0 / 
            (SELECT COUNT(DISTINCT id) FROM fantasy.events WHERE amount > 0) AS buyer_share
    
    FROM fantasy.items AS i
    LEFT JOIN fantasy.events AS e ON i.item_code = e.item_code
    WHERE e.amount > 0  -- Фильтруем нулевые покупки
    
    -- Фильтруем только эпические предметы
    -- (условие фильтрации можно добавить при необходимости)
    
    GROUP BY  i.game_items
)

-- Основной запрос для анализа популярных предметов
SELECT 
    game_items,                      -- Название предмета
    purchasers,                      -- Количество покупателей
    purchase_count,                  -- Количество покупок
    total_revenue,                   -- Общая выручка
    relative_purchase_count,         -- Относительное количество покупок (%)
    buyer_share,                     -- Доля покупателей (%)
    
    -- Среднее количество покупок по всем предметам
    AVG(purchase_count) OVER () AS avg_purchases,
    
    -- Средняя выручка по всем предметам
    AVG(total_revenue) OVER () AS avg_revenue

FROM item_purchases

-- Сортируем по количеству покупок в порядке убывания
ORDER BY purchase_count DESC;

-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
-- Напишите ваш запрос здесь
-- CTE для подсчета общей статистики по игрокам
WITH total_users AS (
 SELECT 
 r.race, -- Раса персонажа
 COUNT(DISTINCT u.id) AS total_users -- Общее количество уникальных пользователей
 FROM fantasy.users AS u
 LEFT JOIN fantasy.race AS r ON u.race_id = r.race_id
 GROUP BY r.race -- Группируем только по расе
),

-- CTE для подсчета всех показателей по покупкам
purchase_summary AS (
 SELECT 
 r.race, -- Раса персонажа
 -- Подсчет платящих пользователей с использованием CASE WHEN
 COUNT(DISTINCT CASE WHEN u.payer = 1 THEN e.id END) AS paying_users,
 COUNT(DISTINCT e.id) AS total_payers, -- Общее количество покупателей
 COUNT(e.id) AS total_events, -- Общее количество событий
 SUM(e.amount) AS total_amount -- Общая сумма транзакций
 FROM fantasy.users AS u
 LEFT JOIN fantasy.events AS e ON u.id = e.id
 LEFT JOIN fantasy.race AS r ON u.race_id = r.race_id
 WHERE e.amount > 0 -- Фильтруем только положительные транзакции
 GROUP BY r.race -- Группируем только по расе
)

-- Основной запрос для расчета всех метрик
SELECT 
 pu.race, -- Раса персонажа
 
 -- Общее количество пользователей
 total_users,
 
 -- Общее количество покупателей
 total_payers,
 
 -- Доля покупателей (%)
 ROUND(CAST(total_payers AS numeric) / total_users * 100, 2) AS buyer_share,
 
 -- Доля платящих пользователей (%)
 ROUND(CAST(paying_users AS numeric) / total_payers * 100, 2) AS paying_share,
 
 -- Среднее количество покупок на пользователя
 ROUND(CAST(total_events AS numeric) / total_payers, 2) AS avg_purchases_per_user,
 
 -- Средняя стоимость одной покупки
 ROUND(CAST(total_amount AS NUMERIC) / total_events, 2) AS avg_purchase_amount,
 
 -- Средняя суммарная стоимость всех покупок
 ROUND(CAST(total_amount AS numeric) / total_payers, 2) AS avg_total_amount

FROM purchase_summary AS pu
JOIN total_users AS tu ON pu.race = tu.race -- Соединяем данные по расе
ORDER BY race; -- Сортируем по расе
-- Задача 2: Частота покупок
-- Напишите ваш запрос здесь
-- CTE для подсчета общего количества покупок и уникальных пользователей
WITH purchase_intervals AS (
    SELECT 
        id,
        amount,
        date,
        LAG(date) OVER (PARTITION BY id ORDER BY date) AS prev_date,
        -- Расчет разницы между датами в виде интервала
        AGE(date::timestamp, LAG(date::timestamp) OVER (PARTITION BY id ORDER BY date::timestamp)) AS days_between
    FROM fantasy.events
    WHERE amount > 0
),

-- CTE для расчета средних показателей по пользователям
user_metrics AS (
    SELECT 
        p.id,
        u.payer,
        COUNT(*) AS purchase_count,
        -- Извлечение только дня из среднего интервала
        EXTRACT(DAY FROM AVG(days_between)) AS avg_days_between,
        -- Определение категории частоты покупок
        CASE 
            
            WHEN AVG(days_between) <= INTERVAL '7 days' THEN 'высокая'
            WHEN AVG(days_between) BETWEEN INTERVAL '8 days' AND INTERVAL '14 days' THEN 'умеренная'
            ELSE 'низкая'
        END AS purchase_frequency
    FROM purchase_intervals p
    JOIN fantasy.users u ON p.id = u.id
    GROUP BY p.id, u.payer
    HAVING COUNT(*) >= 3 -- Минимум 3 покупки для расчета
),

-- Финальный запрос с агрегированием по категориям
final_metrics AS (
    SELECT 
        purchase_frequency,
        COUNT(DISTINCT id) AS total_users,
        SUM(CASE WHEN payer = 1 THEN 1 ELSE 0 END) AS paying_users,
        -- Расчет процента платящих пользователей
        ROUND(
            CAST(SUM(CASE WHEN payer = 1 THEN 1 ELSE 0 END) AS numeric) 
            / COUNT(DISTINCT id) * 100, 
            2
        ) AS paying_percentage,
        ROUND(AVG(purchase_count::NUMERIC), 2) AS avg_purchase_count,
        ROUND(AVG(avg_days_between::INTEGER), 2) AS avg_days_between
    FROM user_metrics
    GROUP BY purchase_frequency
)

SELECT 
    purchase_frequency,
    total_users,
    paying_users,
    paying_percentage,
    avg_purchase_count,
    avg_days_between
FROM final_metrics
ORDER BY 
    CASE purchase_frequency
        WHEN 'высокая' THEN 1
        WHEN 'умеренная' THEN 2
        WHEN 'низкая' THEN 3
    END;