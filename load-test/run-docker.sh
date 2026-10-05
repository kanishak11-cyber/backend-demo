#!/usr/bin/env bash
# Load-tests each backend in its own Docker container with a hard memory cap
# (swap disabled), one at a time. oha runs in a separate container on the same
# Docker network as Postgres (docker-compose.yml), so traffic stays inside the
# Docker VM.
#
# Usage: ./run-docker.sh                                   (/health, 4000 users, 30s, 4g cap)
#        ENDPOINT=/users/random MEMORY=64m,128m,256m,512m ./run-docker.sh
#        ENDPOINT=/users/random/cached MEMORY=64m,128m,256m,512m ./run-docker.sh
#        ONLY=go,rust USERS=1000 DURATION=10s ./run-docker.sh
set -euo pipefail

USERS=${USERS:-4000}
DURATION=${DURATION:-30s}
WARMUP=${WARMUP:-5s}
COOLDOWN=${COOLDOWN:-5}
MEMORY=${MEMORY:-4g}            # one cap, or a comma-separated list
ENDPOINT=${ENDPOINT:-/health}
DB_POOL_SIZE=${DB_POOL_SIZE:-20}
ONLY=${ONLY:-}                  # comma-separated backend names; empty = all

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HERE="$ROOT/load-test"
SLUG=$(echo "$ENDPOINT" | sed 's#^/##; s#[^A-Za-z0-9]#-#g')
OUT="$HERE/results/$(date +%Y%m%d-%H%M%S)-docker-$SLUG"
NET=backend-demo-loadtest
DB_CONTAINER=backend-demo-postgres
REDIS_CONTAINER=backend-demo-redis
DATABASE_URL=postgres://demo:demo@postgres:5432/demo
REDIS_URL=redis://redis:6379

# name|port inside container|project dir|command override (empty = image default)
BACKENDS=(
  "python|8000|Python|uvicorn main:app --host 0.0.0.0 --port 8000 --no-access-log --log-level warning"
  "go|8080|go-lang|"
  "node|3000|node-js|"
  "cpp|8081|C|"
  "rust|8082|rust|"
)
SELECTED=()
for entry in "${BACKENDS[@]}"; do
  name=${entry%%|*}
  if [[ -z "$ONLY" || ",$ONLY," == *",$name,"* ]]; then SELECTED+=("$entry"); fi
done
IFS=',' read -r -a CAPS <<<"$MEMORY"

docker info >/dev/null 2>&1 || { echo "Docker is not running; start Docker Desktop first" >&2; exit 1; }
mkdir -p "$OUT"

echo "Starting Postgres and Redis..."
docker compose -f "$ROOT/docker-compose.yml" up -d --wait postgres redis >/dev/null 2>&1

echo "Building images..."
docker build -q -t backend-demo/oha "$HERE/oha" >/dev/null
docker build -q -t backend-demo/python "$ROOT/Python" >/dev/null  # also runs warm_cache.py
for entry in "${SELECTED[@]}"; do
  IFS='|' read -r name _ dir _ <<<"$entry"
  docker build -q -t "backend-demo/$name" "$ROOT/$dir" >/dev/null
done

CONTAINER=""
SAMPLER_PIDS=()
stop_samplers() {
  for pid in "${SAMPLER_PIDS[@]+"${SAMPLER_PIDS[@]}"}"; do kill "$pid" 2>/dev/null || true; done
  for pid in "${SAMPLER_PIDS[@]+"${SAMPLER_PIDS[@]}"}"; do wait "$pid" 2>/dev/null || true; done
  SAMPLER_PIDS=()
}
cleanup() {
  stop_samplers
  [[ -n "$CONTAINER" ]] && docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

run_oha() {
  docker run --rm --network "$NET" --ulimit nofile=65536:65536 backend-demo/oha "$@"
}

now() { perl -MTime::HiRes=time -e 'printf "%.1f", time'; }
is_running() { [[ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null)" == "true" ]]; }
redis_cli() { docker exec "$REDIS_CONTAINER" redis-cli "$@"; }

# Empties Redis, then for the cached endpoint loads every user into it, so each
# backend starts from the same full cache.
reset_cache() {
  redis_cli FLUSHALL >/dev/null
  if [[ "$ENDPOINT" == */cached ]]; then
    docker run --rm --network "$NET" -e DATABASE_URL="$DATABASE_URL" -e REDIS_URL="$REDIS_URL" \
      -v "$HERE/warm_cache.py:/warm_cache.py:ro" backend-demo/python python /warm_cache.py >/dev/null
  fi
}

# Appends "mem_kb cpu_percent elapsed_s" for a container until it stops or is killed.
# Each `docker stats --no-stream` call takes about a second, which sets the sample rate.
sample_stats() {
  local start
  start=$(now)
  while is_running "$1"; do
    docker stats --no-stream --format '{{.MemUsage}} {{.CPUPerc}}' "$1" 2>/dev/null |
      awk -v t="$(perl -e "printf '%.1f', $(now) - $start")" '{
        n = $1 + 0; u = $1; sub(/^[0-9.]+/, "", u)
        kb = (u == "GiB") ? n * 1048576 : (u == "MiB") ? n * 1024 : (u == "KiB") ? n : n / 1024
        c = $4; sub(/%/, "", c)
        printf "%d %s %s\n", kb, c, t
      }' >>"$2" || true
  done
}

# Waits until the endpoint answers 200; fails early if the container dies.
wait_until_ready() {
  for _ in $(seq 1 60); do
    is_running "$1" || return 1
    run_oha -n 1 -t 1s --no-tui --output-format json "$2" 2>/dev/null | grep -q '"200": *1' && return 0
    sleep 0.25
  done
  return 1
}

# Records why a backend could not be tested at this cap and removes its container.
give_up() {
  local dir=$1 name=$2 when=$3 oom
  oom=$(docker inspect -f '{{.State.OOMKilled}}' "$CONTAINER" 2>/dev/null || echo false)
  if [[ "$oom" == "true" ]]; then echo "killed for exceeding memory $when" >"$dir/$name.failed"
  else echo "stopped $when" >"$dir/$name.failed"; fi
  docker logs "$CONTAINER" >"$dir/$name.server.log" 2>&1 || true
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  CONTAINER=""
  echo "  NOT TESTED: $(cat "$dir/$name.failed")"
}

write_config() {
  cat >"$1/config.json" <<EOF
{"users": $USERS, "duration": "$DURATION", "warmup": "$WARMUP",
 "endpoint": "$ENDPOINT", "db_pool_size": $DB_POOL_SIZE,
 "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
 "cpu": "$(sysctl -n machdep.cpu.brand_string)", "cores": $(sysctl -n hw.ncpu),
 "memory_gb": $(($(sysctl -n hw.memsize) / 1024 / 1024 / 1024)),
 "oha": "$(run_oha --version | awk '{print $2}')",
 "memory_limit": "$2",
 "environment": "Docker VM: $(docker info --format '{{.NCPU}} CPUs, {{.MemTotal}}' | awk '{printf "%s %s %.1f GB", $1, $2, $3 / 1024 / 1024 / 1024}') RAM, $(docker info --format '{{.KernelVersion}}') kernel"}
EOF
}

total=$((${#CAPS[@]} * ${#SELECTED[@]}))
run=0
for cap in "${CAPS[@]}"; do
  dir="$OUT/$cap"
  mkdir -p "$dir"
  write_config "$dir" "$cap"

  for entry in "${SELECTED[@]}"; do
    IFS='|' read -r name port _ cmd <<<"$entry"
    run=$((run + 1))
    CONTAINER="lt-$name"
    url="http://$CONTAINER:$port$ENDPOINT"

    echo
    echo "=== [$run/$total] $name, memory cap $cap, GET $ENDPOINT ==="
    docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
    reset_cache
    # shellcheck disable=SC2086  # $cmd is intentionally split into arguments
    docker run -d --name "$CONTAINER" --network "$NET" \
      --memory "$cap" --memory-swap "$cap" \
      --ulimit nofile=65536:65536 \
      -e DATABASE_URL="$DATABASE_URL" -e DB_POOL_SIZE="$DB_POOL_SIZE" -e REDIS_URL="$REDIS_URL" \
      "backend-demo/$name" $cmd >/dev/null

    if ! wait_until_ready "$CONTAINER" "$url"; then
      give_up "$dir" "$name" "while starting"
      continue
    fi

    run_oha -c 100 -z "$WARMUP" --no-tui "$url" >/dev/null
    if ! is_running "$CONTAINER"; then
      give_up "$dir" "$name" "during warm-up"
      continue
    fi

    sample_stats "$CONTAINER" "$dir/$name.stats" &
    SAMPLER_PIDS+=($!)
    sample_stats "$DB_CONTAINER" "$dir/$name.db.stats" &
    SAMPLER_PIDS+=($!)
    sample_stats "$REDIS_CONTAINER" "$dir/$name.redis.stats" &
    SAMPLER_PIDS+=($!)
    redis_cli CONFIG RESETSTAT >/dev/null
    run_oha -c "$USERS" -z "$DURATION" -w -t 30s --no-tui --output-format json "$url" >"$dir/$name.json"
    stop_samplers
    # "hits misses" during the measured window only (stats were reset after warm-up)
    redis_cli INFO stats | tr -d '\r' | awk -F: '/^keyspace_hits/ {h = $2} /^keyspace_misses/ {m = $2} END {print h, m}' >"$dir/$name.cache"

    oom=$(docker inspect -f '{{.State.OOMKilled}}' "$CONTAINER")
    [[ "$oom" == "true" ]] && echo yes >"$dir/$name.oom" || echo no >"$dir/$name.oom"
    docker logs "$CONTAINER" >"$dir/$name.server.log" 2>&1 || true
    docker rm -f "$CONTAINER" >/dev/null
    CONTAINER=""

    python3 "$HERE/summarize.py" "$dir" --only "$name"
    echo "  killed for exceeding memory: $(cat "$dir/$name.oom")"

    if ((run < total)); then sleep "$COOLDOWN"; fi
  done

  if ls "$dir"/*.json >/dev/null 2>&1; then python3 "$HERE/summarize.py" "$dir" >/dev/null; fi
done

echo
if ((${#CAPS[@]} > 1)); then
  python3 "$HERE/summarize.py" --matrix "$OUT"
else
  cat "$OUT/${CAPS[0]}/summary.md" 2>/dev/null || true
fi
echo
echo "Raw results: $OUT"
