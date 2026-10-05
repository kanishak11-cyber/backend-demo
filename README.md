# One API, five languages

The same small HTTP API written in **Python, Go, Node.js, C++ and Rust**, load-tested with 4,000 concurrent users, with and without a database, with and without a Redis cache, and under memory limits from 4 GB down to 64 MB.

All raw results are in [`load-test/results/`](load-test/results).

## What's here

| Folder | Language | Framework | Database / cache clients | Port |
|---|---|---|---|---|
| [`Python/`](Python) | Python 3.13 | FastAPI + uvicorn | asyncpg, redis-py | 8000 |
| [`go-lang/`](go-lang) | Go 1.27 | net/http (standard library) | pgx, go-redis | 8080 |
| [`node-js/`](node-js) | Node.js 22 | Express 5 | pg, node-redis | 3000 |
| [`C/`](C) | C++17 | Crow | libpq, hiredis | 8081 |
| [`rust/`](rust) | Rust (2024 edition) | axum + tokio | sqlx, redis | 8082 |

- [`docker-compose.yml`](docker-compose.yml) runs Postgres 18 and Redis 8.
- [`db/init/`](db/init) creates the `users` table and seeds 100,000 random users on first start.
- [`load-test/`](load-test) has the load-test scripts and every result.

## The API

Every backend serves the same three endpoints with the same JSON:

| Endpoint | What it does |
|---|---|
| `GET /health` | Returns status, service name, uptime and timestamp. No database. |
| `GET /users/random` | Picks a random user ID and reads that user from Postgres. |
| `GET /users/random/cached` | Checks Redis first; on a miss reads Postgres and caches the user for 5 minutes. Sets an `X-Cache: HIT` or `MISS` header. |

```json
{"id":41468,"name":"Liam Reddy","email":"liam.reddy.41468@example.com","age":71,"city":"Singapore","created_at":"2025-12-16T17:13:06Z"}
```

Each backend uses 20 pooled Postgres connections. For Redis, Python and Go use a pool of 20, C++ uses one connection per worker thread, and Node.js and Rust share one pipelined connection.

## Run it

Start Postgres (host port 5434) and Redis (port 6379):

```sh
docker compose up -d --wait
```

Then start any backend:

```sh
cd Python  && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt && .venv/bin/uvicorn main:app --port 8000
cd go-lang && go run .
cd node-js && npm install && npm start
cd C       && make run                 # needs: brew install crow libpq hiredis pkgconf
cd rust    && cargo run --release
```

```sh
curl localhost:8080/users/random/cached -i
```

Each folder also has a `Dockerfile`, for example `docker build -t api ./rust && docker run --memory=256m -p 8082:8082 --network backend-demo-loadtest -e DATABASE_URL=postgres://demo:demo@postgres:5432/demo -e REDIS_URL=redis://redis:6379 api`.

## Load tests

| Script | What it does |
|---|---|
| [`load-test/run-docker.sh`](load-test/run-docker.sh) | Runs each backend in its own Docker container with a hard memory limit (swap off), one at a time. The load generator runs in a container on the same network. |
| [`load-test/run.sh`](load-test/run.sh) | Runs each backend natively on the host. |
| [`load-test/summarize.py`](load-test/summarize.py) | Turns raw results into `summary.md`, `summary.csv`, `matrix.md` and `matrix.csv`. |
| [`load-test/warm_cache.py`](load-test/warm_cache.py) | Loads all 100,000 users into Redis before each cached run. |

```sh
cd load-test
./run-docker.sh                                                        # /health, 4 GB limit
ENDPOINT=/users/random        MEMORY=64m,128m,256m,512m ./run-docker.sh
ENDPOINT=/users/random/cached MEMORY=64m,128m,256m,512m ./run-docker.sh
ONLY=go,rust USERS=1000 DURATION=10s ./run-docker.sh                   # smaller run
```

**How each run works:** [oha](https://github.com/hatoo/oha) 1.16 opens 4,000 keep-alive connections and sends requests for 30 seconds after a 5-second warm-up that isn't counted. Requests still in flight at 30 seconds are allowed to finish. Only HTTP 200 responses count as successful, since oha's own requests-per-second figure includes failed attempts. Memory and CPU come from `docker stats` about once a second, and out-of-memory kills come from `docker inspect`.

## Results

Measured on 5 October 2026 on a MacBook Air M3 (8 cores, 24 GB). Docker's Linux VM had 8 CPUs and 7.7 GB of RAM.

### 1. `GET /health`, 4 GB limit per backend

```mermaid
xychart-beta
    title "GET /health, 4,000 users, 4 GB RAM (successful requests per second)"
    x-axis ["C++", "Rust", "Go", "Node.js", "Python"]
    y-axis "Requests per second" 0 --> 300000
    bar [269725, 247393, 235129, 13172, 7016]
```

| Backend | Requests/s | Success | p50 | p99 | Peak memory | CPU cores |
|---|---:|---:|---:|---:|---:|---:|
| C++ | 269,725 | 100.00% | 13.7 ms | 39.8 ms | 59 MB | 4.0 |
| Rust | 247,393 | 100.00% | 11.9 ms | 48.6 ms | 122 MB | 3.9 |
| Go | 235,129 | 100.00% | 16.0 ms | 76.2 ms | 177 MB | 4.0 |
| Node.js | 13,172 | 99.24% | 65.8 ms | 131.3 ms | 175 MB | 0.8 |
| Python | 7,016 | 100.00% | 524.3 ms | 1,787.8 ms | 153 MB | 1.0 |

No backend came close to 4 GB. Python and Node.js run as a single process on one core, which explains most of their gap.

### 2. `GET /users/random` (Postgres) under memory limits

Successful requests per second. 💥 means the container was killed for exceeding its memory limit; the number is averaged over the whole 30 seconds.

| Backend | 64 MB | 128 MB | 256 MB | 512 MB |
|---|---:|---:|---:|---:|
| C++ | 105,608 | 99,016 | 62,949 | 54,214 |
| Rust | 💥 4 | 💥 1,050 | 23,517 | 21,494 |
| Go | 💥 9 | 💥 51 | 32,369 | 38,202 |
| Node.js | 💥 591 | 9,094 | 6,069 | 4,388 |
| Python | 💥 53 | 💥 343 | 915 | 4,479 |

Peak memory of the backends that survived:

| Backend | 64 MB | 128 MB | 256 MB | 512 MB |
|---|---:|---:|---:|---:|
| C++ | 62 MB | 63 MB | 63 MB | 61 MB |
| Rust | killed | killed | 180 MB | 170 MB |
| Go | killed | killed | 218 MB | 219 MB |
| Node.js | killed | 123 MB | 116 MB | 118 MB |
| Python | killed | killed | 145 MB | 146 MB |

### 3. `GET /users/random/cached` (Redis in front of Postgres) under memory limits

Redis was pre-filled with all 100,000 users before each run, so every run had a 100% hit rate.

| Backend | 64 MB | 128 MB | 256 MB | 512 MB |
|---|---:|---:|---:|---:|
| C++ | 144,337 | 136,044 | 83,078 | 91,724 |
| Rust | 💥 401 | 💥 19,540 | 117,369 | 118,186 |
| Go | 💥 8 | 💥 20 | 56,848 | 61,048 |
| Node.js | 💥 30 | 11,325 | 6,916 | 8,299 |
| Python | 💥 0 | 💥 939 | 7,548 | 8,104 |

| Backend | 64 MB | 128 MB | 256 MB | 512 MB |
|---|---:|---:|---:|---:|
| C++ | 62 MB | 62 MB | 62 MB | 62 MB |
| Rust | killed | killed | 128 MB | 127 MB |
| Go | killed | killed | 226 MB | 228 MB |
| Node.js | killed | 127 MB | 116 MB | 116 MB |
| Python | killed | killed | 159 MB | 159 MB |

### 4. Postgres only vs with Redis, 512 MB

```mermaid
xychart-beta
    title "GET /users/random/cached, 4,000 users, 512 MB RAM (successful requests per second)"
    x-axis ["Rust", "C++", "Go", "Node.js", "Python"]
    y-axis "Requests per second" 0 --> 130000
    bar [118186, 91724, 61048, 8299, 8104]
```

| Backend | Postgres only | With Redis | Change |
|---|---:|---:|---:|
| Rust | 21,494 | 118,186 | 5.5× |
| C++ | 54,214 | 91,724 | 1.7× |
| Go | 38,202 | 61,048 | 1.6× |
| Node.js | 4,388 | 8,299 | 1.9× |
| Python | 4,479 | 8,104 | 1.8× |

With Redis, Postgres CPU dropped from up to about 3.5 cores to about 1–3% of one core. During the C++ runs Redis itself was 84–88% busy on its single core, so Redis was C++'s limit.

### 5. Native on macOS, `GET /health` (Python, Go and Node.js only)

| Backend | Requests/s | Success | p50 | p99 |
|---|---:|---:|---:|---:|
| Go | 176,102 | 99.96% | 21.3 ms | 66.3 ms |
| Node.js | 18,125 | 31.4% | 118.2 ms | 266.4 ms |
| Python | 8,000 | 41.7% | 429.1 ms | 792.4 ms |

On macOS, Python and Node.js failed most connection attempts while holding 4,000 connections. Inside Docker (Linux) the same servers failed under 1%.

## Findings

- **Raw speed:** C++, Rust and Go are in the same league when they can use all cores. Single-process Python and Node.js are an order of magnitude behind.
- **Memory:** C++ needed about 62 MB for 4,000 connections in every test and was the only backend to survive 64 MB. Node.js needed about 120 MB, Rust 130–180 MB, Python about 150 MB and Go about 220 MB.
- **Redis speeds things up but doesn't save memory.** Memory goes into holding 4,000 open connections, not into the data.
- **The database driver can matter more than the language.** Rust was third with Postgres (sqlx) and first with Redis.
- **Defaults matter.** Go's garbage collector doesn't know about the container limit unless `GOMEMLIMIT` is set; none of the backends were tuned.

## Caveats

- **One laptop.** The load generator, the databases and the backend share the same 8 cores.
- **Heat.** The MacBook Air has no fan and slows down under long load. The same C++ test (64 MB, Postgres) did 105,608 requests/s at the start of a 20-run batch, 74,710 right after it, and 92,789 after 5 minutes of rest. Within one table, later columns are affected. The Postgres and Redis batches used the same order and timing, so the same cell is comparable across them.
- **No tuning.** Python runs one uvicorn worker, Node.js runs one process, Go has no `GOMEMLIMIT`.
- **C++ fix between runs.** Crow ships with `TCP_NODELAY` off. That made the cached endpoint crawl (451 requests/s), so `app.tcp_nodelay()` was added before the Redis batch. It went to 136,258 requests/s. The `/health` and Postgres results for C++ were measured before this change.

This is a learning benchmark, not a verdict.

## Raw data

| Folder | Run |
|---|---|
| [`20261005-215715`](load-test/results/20261005-215715) | Native macOS, `/health`, Python, Go and Node.js (includes `report.html` charts) |
| [`20261005-223318-docker-4g`](load-test/results/20261005-223318-docker-4g) | Docker, `/health`, 4 GB limit, all five |
| [`20261005-225546-docker-users-random`](load-test/results/20261005-225546-docker-users-random) | Docker, Postgres, 64–512 MB, all five |
| [`20261005-233416-docker-users-random-cached`](load-test/results/20261005-233416-docker-users-random-cached) | Docker, Redis + Postgres, 64–512 MB, all five |
| [`20261005-231225-docker-users-random`](load-test/results/20261005-231225-docker-users-random) | Heat check: C++ at 64 MB right after the Postgres batch |
| [`20261005-231815-docker-users-random`](load-test/results/20261005-231815-docker-users-random) | Heat check: C++ at 64 MB after 5 minutes of rest |

Each run folder has one sub-folder per memory limit (Docker runs) with oha's full JSON output per backend, memory and CPU samples (`*.stats`), server logs, and `summary.md` / `summary.csv`. Multi-limit runs also have `matrix.md` / `matrix.csv`.
