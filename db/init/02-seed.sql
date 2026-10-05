-- 100,000 random users. setseed() makes every fresh database get the same data.
SELECT setseed(0.42);

WITH pools AS (
    SELECT
        ARRAY['Aarav', 'Aditi', 'Arjun', 'Diya', 'Ishaan', 'Kavya', 'Rohan', 'Saanvi', 'Vihaan', 'Ananya',
              'Liam', 'Olivia', 'Noah', 'Emma', 'Mateo', 'Sofia', 'Yuki', 'Hana', 'Omar', 'Layla'] AS first_names,
        ARRAY['Sharma', 'Patel', 'Iyer', 'Reddy', 'Gupta', 'Nair', 'Singh', 'Khan', 'Das', 'Mehta',
              'Smith', 'Garcia', 'Kim', 'Tanaka', 'Silva', 'Muller', 'Rossi', 'Ali', 'Chen', 'Novak'] AS last_names,
        ARRAY['Mumbai', 'Delhi', 'Bengaluru', 'Pune', 'Hyderabad', 'Chennai',
              'London', 'New York', 'Tokyo', 'Berlin', 'Dubai', 'Singapore'] AS cities
),
people AS (
    SELECT
        g,
        first_names[1 + floor(random() * cardinality(first_names))::int] AS first_name,
        last_names[1 + floor(random() * cardinality(last_names))::int] AS last_name,
        cities[1 + floor(random() * cardinality(cities))::int] AS city
    FROM pools, generate_series(1, 100000) AS g
)
INSERT INTO users (name, email, age, city, created_at)
SELECT
    first_name || ' ' || last_name,
    lower(first_name || '.' || last_name || '.' || g) || '@example.com',
    18 + floor(random() * 63)::int,
    city,
    now() - random() * interval '3 years'
FROM people
ORDER BY g;

ANALYZE users;
