-- 1. Вывести количество фильмов в каждой категории, отсортировать по убыванию
SELECT 
    c.name AS category_name, 
    COUNT(fc.film_id) AS films_count
FROM 
    public.film_category fc
INNER JOIN
    public.category c ON fc.category_id = c.category_id 
GROUP BY 
    c.name
ORDER BY 
    films_count DESC;

-- 2. Вывести 10 актеров, чьи фильмы больше всего арендовали, отсортировать по убыванию
SELECT 
    CONCAT(a.first_name, ' ', a.last_name) AS actor_name,
    COUNT(r.rental_id) AS rental_count
FROM 
    public.actor a
INNER JOIN 
    public.film_actor fa ON a.actor_id = fa.actor_id
INNER JOIN 
    public.film f ON f.film_id = fa.film_id
LEFT JOIN 
    public.inventory i ON f.film_id = i.film_id
LEFT JOIN 
    public.rental r ON i.inventory_id = r.inventory_id
GROUP BY 
    a.actor_id, a.first_name, a.last_name
ORDER BY 
    rental_count DESC
LIMIT 10;

-- 3. Вывести категорию фильмов, на которую потратили больше всего денег
SELECT 
    c.name AS category_name, 
    SUM(p.amount) AS total_revenue
FROM 
    public.category c 
INNER JOIN 
    public.film_category fc ON c.category_id = fc.category_id
LEFT JOIN 
    public.film f ON f.film_id = fc.film_id
LEFT JOIN 
    public.inventory i ON f.film_id = i.film_id
LEFT JOIN 
    public.rental r ON i.inventory_id = r.inventory_id
LEFT JOIN 
    public.payment p ON p.rental_id = r.rental_id
GROUP BY 
    c.name
ORDER BY 
    total_revenue DESC
LIMIT 1;

-- 4. Вывести названия фильмов, которых нет в inventory. Без использования оператора IN
SELECT 
    f.title AS missing_film_title
FROM  
    public.film f 
LEFT OUTER JOIN 
    public.inventory i ON f.film_id = i.film_id 
WHERE 
    i.inventory_id IS NULL;

-- 5. Вывести топ 3 актеров, которые больше всего появлялись в фильмах категории "Children"
-- Если у нескольких актеров одинаковое кол-во фильмов, вывести всех
WITH actor_children_stats AS (
    SELECT 
        a.actor_id,
        CONCAT(a.first_name, ' ', a.last_name) AS actor_name,
        COUNT(fc.film_id) AS films_count
    FROM 
        public.actor a
    INNER JOIN 
        public.film_actor fa ON a.actor_id = fa.actor_id
    INNER JOIN 
        public.film_category fc ON fa.film_id = fc.film_id
    INNER JOIN 
        public.category c ON fc.category_id = c.category_id
    WHERE 
        c.name = 'Children'
    GROUP BY 
        a.actor_id, a.first_name, a.last_name
),
ranked_actors AS (
    SELECT 
        actor_id,
        actor_name,
        films_count,
        DENSE_RANK() OVER (ORDER BY films_count DESC) AS rank
    FROM 
        actor_children_stats
)
SELECT 
    actor_name,
    films_count
FROM 
    ranked_actors
WHERE 
    rank <= 3
ORDER BY 
    films_count DESC, 
    actor_name;

-- 6. Вывести города с количеством активных и неактивных клиентов
-- (активный — customer.active = 1). Сортировка по количеству неактивных клиентов по убыванию
WITH active_customers AS (
    SELECT 
        c.city_id,
        c.city,
        COUNT(cust.customer_id) AS active_count
    FROM 
        public.customer cust
    INNER JOIN 
        public.address a ON cust.address_id = a.address_id  
    INNER JOIN 
        public.city c ON a.city_id = c.city_id
    WHERE 
        cust.active = 1
    GROUP BY 
        c.city_id, c.city
),
inactive_customers AS (
    SELECT 
        c.city_id,
        c.city,
        COUNT(cust.customer_id) AS inactive_count
    FROM 
        public.customer cust
    INNER JOIN 
        public.address a ON cust.address_id = a.address_id  
    INNER JOIN 
        public.city c ON a.city_id = c.city_id
    WHERE 
        cust.active = 0
    GROUP BY 
        c.city_id, c.city
)
SELECT 
    COALESCE(a.city, i.city) AS city,
    COALESCE(a.active_count, 0) AS active_customers,
    COALESCE(i.inactive_count, 0) AS inactive_customers
FROM 
    active_customers a
FULL OUTER JOIN 
    inactive_customers i ON a.city_id = i.city_id
ORDER BY 
    inactive_customers DESC;

-- 7. Вывести категорию фильмов с наибольшим суммарным временем аренды:
--    - В городах, названия которых начинаются на "a"
--    - В городах, содержащих символ "-"
--    В одном запросе
WITH category_stats_for_cities_starting_with_a AS (
    SELECT 
        cat.name AS category_name,
        SUM(f.length) AS total_rental_hours
    FROM 
        public.rental r
    JOIN public.inventory i ON r.inventory_id = i.inventory_id
    JOIN public.film f ON i.film_id = f.film_id
    JOIN public.film_category fc ON f.film_id = fc.film_id
    JOIN public.category cat ON fc.category_id = cat.category_id
    JOIN public.customer cust ON r.customer_id = cust.customer_id
    JOIN public.address a ON cust.address_id = a.address_id
    JOIN public.city c ON a.city_id = c.city_id
    WHERE 
        c.city LIKE 'a%'
    GROUP BY 
        cat.name
    ORDER BY 
        total_rental_hours DESC
    LIMIT 1
),
category_stats_for_cities_with_dash AS (
    SELECT 
        cat.name AS category_name,
        SUM(f.length) AS total_rental_hours
    FROM 
        public.rental r
    JOIN public.inventory i ON r.inventory_id = i.inventory_id
    JOIN public.film f ON i.film_id = f.film_id
    JOIN public.film_category fc ON f.film_id = fc.film_id
    JOIN public.category cat ON fc.category_id = cat.category_id
    JOIN public.customer cust ON r.customer_id = cust.customer_id
    JOIN public.address a ON cust.address_id = a.address_id
    JOIN public.city c ON a.city_id = c.city_id
    WHERE 
        c.city LIKE '%-%'
    GROUP BY 
        cat.name
    ORDER BY 
        total_rental_hours DESC
    LIMIT 1
)
SELECT 
    'Cities starting with "a"' AS city_filter,
    category_name,
    total_rental_hours
FROM 
    category_stats_for_cities_starting_with_a
UNION ALL
SELECT 
    'Cities containing "-"' AS city_filter,
    category_name,
    total_rental_hours
FROM 
    category_stats_for_cities_with_dash;