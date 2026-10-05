import express from "express";
import pg from "pg";
import { createClient } from "redis";

const PORT = process.env.PORT || 3000;
const DATABASE_URL = process.env.DATABASE_URL || "postgres://demo:demo@localhost:5434/demo";
const DB_POOL_SIZE = Number(process.env.DB_POOL_SIZE || 20);
const REDIS_URL = process.env.REDIS_URL || "redis://localhost:6379";
const CACHE_TTL_SECONDS = 300;

const USER_QUERY = `
  SELECT id, name, email, age, city,
         to_char(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at
  FROM users
  WHERE id = $1`;

const pool = new pg.Pool({ connectionString: DATABASE_URL, max: DB_POOL_SIZE });
const { rows } = await pool.query("SELECT coalesce(max(id), 0) AS max_id FROM users");
const maxUserId = rows[0].max_id;

// One connection; node-redis pipelines concurrent commands over it.
const cache = await createClient({ url: REDIS_URL }).connect();

// A named query is prepared once per connection and reused.
async function loadUser(id) {
  const result = await pool.query({ name: "random-user", text: USER_QUERY, values: [id] });
  return result.rows[0] ?? null;
}

const pickUserId = () => 1 + Math.floor(Math.random() * maxUserId);

const app = express();

app.get("/health", (req, res) => {
  res.json({
    status: "ok",
    service: "node-service",
    uptime_seconds: Number(process.uptime().toFixed(3)),
    timestamp: new Date().toISOString(),
  });
});

app.get("/users/random", async (req, res) => {
  if (!maxUserId) {
    return res.status(404).json({ detail: "no users" });
  }
  const user = await loadUser(pickUserId());
  if (!user) {
    return res.status(404).json({ detail: "user not found" });
  }
  res.json(user);
});

// Same as /users/random, but checks Redis first and caches misses.
app.get("/users/random/cached", async (req, res) => {
  if (!maxUserId) {
    return res.status(404).json({ detail: "no users" });
  }
  const id = pickUserId();
  const key = `user:${id}`;

  const cached = await cache.get(key);
  if (cached !== null) {
    return res.type("application/json").set("X-Cache", "HIT").send(cached);
  }

  const user = await loadUser(id);
  if (!user) {
    return res.status(404).json({ detail: "user not found" });
  }
  const body = JSON.stringify(user);
  await cache.setEx(key, CACHE_TTL_SECONDS, body);
  res.type("application/json").set("X-Cache", "MISS").send(body);
});

app.listen(PORT, () => {
  console.log(`node-service listening on :${PORT}`);
});
