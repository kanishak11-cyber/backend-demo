"""Loads every user into Redis under the same key and JSON shape the backends use,
so a load test on /users/random/cached measures the cache-hit path from the start.

run-docker.sh runs this inside the backend-demo/python image, which already has
asyncpg and redis installed.
"""

import asyncio
import json
import os

import asyncpg
import redis.asyncio as redis

CACHE_TTL_SECONDS = 300

QUERY = """
    SELECT id, name, email, age, city,
           to_char(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at
    FROM users
"""


async def main():
    conn = await asyncpg.connect(os.environ["DATABASE_URL"])
    cache = redis.from_url(os.environ["REDIS_URL"])
    rows = await conn.fetch(QUERY)
    async with cache.pipeline(transaction=False) as pipe:
        for row in rows:
            body = json.dumps(dict(row), separators=(",", ":"))
            pipe.set(f"user:{row['id']}", body, ex=CACHE_TTL_SECONDS)
        await pipe.execute()
    print(f"cached {len(rows):,} users")
    await cache.aclose()
    await conn.close()


asyncio.run(main())
