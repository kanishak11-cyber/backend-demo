#!/usr/bin/env bash
# Load-tests each backend's /health endpoint one at a time with oha,
# sampling the server's memory/CPU while the test runs.
#
# Usage: ./run.sh                 (4000 users, 30s per backend, GET /health)
#        ENDPOINT=/users/random USERS=1000 DURATION=10s ./run.sh
set -euo pipefail

USERS=${USERS:-4000}
DURATION=${DURATION:-30s}
WARMUP=${WARMUP:-5s}
COOLDOWN=${COOLDOWN:-10}
ENDPOINT=${ENDPOINT:-/health}

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HERE="$ROOT/load-test"
OUT="$HERE/results/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT" "$HERE/bin"

# Each of the 4000 connections needs a file descriptor on both sides.
ulimit -n 65536

for tool in oha curl python3 go make cargo docker; do
  command -v "$tool" >/dev/null || { echo "missing required tool: $tool" >&2; exit 1; }
done

# Dedicated ports so the test never hits a dev server you already have running.
# name|port|project dir|start command
BACKENDS=(
  "python|18000|Python|.venv/bin/uvicorn main:app --host 127.0.0.1 --port 18000 --no-access-log --log-level warning"
  "go|18080|go-lang|env PORT=18080 $HERE/bin/go-service"
  "node|13000|node-js|env NODE_ENV=production PORT=13000 node index.js"
  "cpp|18081|C|env PORT=18081 ./server"
  "rust|18082|rust|env PORT=18082 ./target/release/rust-service"
)

# Every backend connects to Postgres (localhost:5434) and Redis (localhost:6379) at startup.
echo "Starting Postgres and Redis..."
docker compose -f "$ROOT/docker-compose.yml" up -d --wait postgres redis >/dev/null 2>&1

echo "Building Go, C++ and Rust binaries..."
(cd "$ROOT/go-lang" && go build -o "$HERE/bin/go-service" .)
make -s -C "$ROOT/C"
(cd "$ROOT/rust" && cargo build --release -q)

SERVER_PID=""
SAMPLER_PID=""
cleanup() {
  [[ -n "$SAMPLER_PID" ]] && kill "$SAMPLER_PID" 2>/dev/null || true
  [[ -n "$SERVER_PID" ]] && kill "$SERVER_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# Appends "rss_kb cpu_percent" for a PID once per second until killed.
sample_stats() {
  while kill -0 "$1" 2>/dev/null; do
    ps -o rss=,%cpu= -p "$1" >>"$2" 2>/dev/null || true
    sleep 1
  done
}

wait_until_ready() {
  for _ in $(seq 1 50); do
    curl -sf "$1" >/dev/null && return 0
    sleep 0.2
  done
  echo "server at $1 did not become ready" >&2
  return 1
}

cat >"$OUT/config.json" <<EOF
{"users": $USERS, "duration": "$DURATION", "warmup": "$WARMUP",
 "endpoint": "$ENDPOINT",
 "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
 "cpu": "$(sysctl -n machdep.cpu.brand_string)", "cores": $(sysctl -n hw.ncpu),
 "memory_gb": $(($(sysctl -n hw.memsize) / 1024 / 1024 / 1024)),
 "oha": "$(oha --version | awk '{print $2}')"}
EOF

for i in "${!BACKENDS[@]}"; do
  IFS='|' read -r name port dir cmd <<<"${BACKENDS[$i]}"
  url="http://127.0.0.1:$port$ENDPOINT"

  echo
  echo "=== [$((i + 1))/${#BACKENDS[@]}] $name ($url) ==="
  if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "port $port is already in use; stop that process first" >&2
    exit 1
  fi
  (cd "$ROOT/$dir" && exec $cmd) >"$OUT/$name.server.log" 2>&1 &
  SERVER_PID=$!
  wait_until_ready "http://127.0.0.1:$port/health"
  if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "$name server exited; see $OUT/$name.server.log" >&2
    exit 1
  fi

  echo "warming up for $WARMUP (not recorded)..."
  oha -c 100 -z "$WARMUP" --no-tui "$url" >/dev/null

  echo "load testing: $USERS concurrent users for $DURATION..."
  sample_stats "$SERVER_PID" "$OUT/$name.stats" &
  SAMPLER_PID=$!
  oha -c "$USERS" -z "$DURATION" -w -t 30s --no-tui --output-format json "$url" >"$OUT/$name.json"

  kill "$SAMPLER_PID" 2>/dev/null || true
  kill "$SERVER_PID" 2>/dev/null || true
  wait "$SERVER_PID" 2>/dev/null || true
  SAMPLER_PID=""
  SERVER_PID=""

  python3 "$HERE/summarize.py" "$OUT" --only "$name"

  if ((i < ${#BACKENDS[@]} - 1)); then
    echo "cooling down ${COOLDOWN}s..."
    sleep "$COOLDOWN"
  fi
done

echo
python3 "$HERE/summarize.py" "$OUT"
echo
echo "Raw results: $OUT"
