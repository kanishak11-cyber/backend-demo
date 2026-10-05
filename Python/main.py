import json
import os
import random
import time
from contextlib import asynccontextmanager
from datetime import datetime, timezone

import asyncpg
import redis.asyncio as redis
from fastapi import FastAPI, HTTPException, Request, Response

DATABASE_URL = os.environ.get("DATABASE_URL", "postgres://demo:demo@localhost:5434/demo")
DB_POOL_SIZE = int(os.environ.get("DB_POOL_SIZE", "20"))
REDIS_URL = os.environ.get("REDIS_URL", "redis://localhost:6379")
REDIS_POOL_SIZE = int(os.environ.get("REDIS_POOL_SIZE", "20"))
CACHE_TTL_SECONDS = 300

USER_QUERY = """
    SELECT id, name, email, age, city,
           to_char(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at
    FROM users
    WHERE id = $1
"""

START_TIME = time.monotonic()


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.pool = await asyncpg.create_pool(
        DATABASE_URL, min_size=DB_POOL_SIZE, max_size=DB_POOL_SIZE
    )
    app.state.max_user_id = await app.state.pool.fetchval(
        "SELECT coalesce(max(id), 0) FROM users"
    )
    app.state.cache = redis.Redis(
        connection_pool=redis.BlockingConnectionPool.from_url(
            REDIS_URL, max_connections=REDIS_POOL_SIZE
        )
    )
    await app.state.cache.ping()
    yield
    await app.state.cache.aclose()
    await app.state.pool.close()


app = FastAPI(title="python-service", lifespan=lifespan)


@app.get("/health")
def health():
    return {
        "status": "ok",
        "service": "python-service",
        "uptime_seconds": round(time.monotonic() - START_TIME, 3),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


def pick_user_id(request: Request) -> int:
    max_user_id = request.app.state.max_user_id
    if not max_user_id:
        raise HTTPException(status_code=404, detail="no users")
    return random.randint(1, max_user_id)


@app.get("/users/random")
async def random_user(request: Request):
    row = await request.app.state.pool.fetchrow(USER_QUERY, pick_user_id(request))
    if row is None:
        raise HTTPException(status_code=404, detail="user not found")
    return dict(row)


@app.get("/users/random/cached")
async def random_user_cached(request: Request):
    """Same as /users/random, but checks Redis first and caches misses."""
    user_id = pick_user_id(request)
    key = f"user:{user_id}"
    state = request.app.state

    cached = await state.cache.get(key)
    if cached is not None:
        return Response(cached, media_type="application/json", headers={"X-Cache": "HIT"})

    row = await state.pool.fetchrow(USER_QUERY, user_id)
    if row is None:
        raise HTTPException(status_code=404, detail="user not found")
    body = json.dumps(dict(row), separators=(",", ":"))
    await state.cache.set(key, body, ex=CACHE_TTL_SECONDS)
    return Response(body, media_type="application/json", headers={"X-Cache": "MISS"})
