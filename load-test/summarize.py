"""Turns oha JSON + server stat samples from run.sh into summary.md / summary.csv."""

import argparse
import csv
import json
from pathlib import Path

BACKENDS = ["python", "go", "node", "cpp", "rust"]


def load_stats(path: Path):
    """Returns (peak_rss_mb, avg_cpu_percent, peak_cpu_percent) from `ps`/`docker stats` samples."""
    if not path.exists():
        return None, None, None
    rss, cpu = [], []
    for line in path.read_text().splitlines():
        parts = line.split()
        # docker stats reports 0 B once a container has been killed; skip those samples.
        if len(parts) >= 2 and int(parts[0]) > 0:
            rss.append(int(parts[0]))
            cpu.append(float(parts[1]))
    if not rss:
        return None, None, None
    return max(rss) / 1024, sum(cpu) / len(cpu), max(cpu)


def summarize(out: Path, name: str):
    data = json.loads((out / f"{name}.json").read_text())
    s = data["summary"]
    lat = data["latencyPercentiles"]
    status = data.get("statusCodeDistribution", {})
    errors = data.get("errorDistribution", {})
    peak_mb, avg_cpu, peak_cpu = load_stats(out / f"{name}.stats")
    _, db_avg_cpu, _ = load_stats(out / f"{name}.db.stats")  # Postgres, run-docker.sh only
    _, redis_avg_cpu, _ = load_stats(out / f"{name}.redis.stats")
    hit_rate = None
    cache_file = out / f"{name}.cache"  # "hits misses" from Redis INFO
    if cache_file.exists():
        hits, misses = (int(x) for x in cache_file.read_text().split())
        hit_rate = hits / (hits + misses) * 100 if hits + misses else None
    oom_file = out / f"{name}.oom"  # written by run-docker.sh only
    oom_killed = oom_file.read_text().strip() if oom_file.exists() else None

    responses = sum(status.values())
    error_count = sum(errors.values())
    ms = lambda v: v * 1000 if v is not None else None  # noqa: E731

    ok = status.get("200", 0)
    return {
        "backend": name,
        # oha's requestsPerSec also counts failed attempts, so derive throughput from 200s.
        "requests_per_sec": ok / s["total"],
        "attempts_per_sec": s["requestsPerSec"],
        "total_requests": responses + error_count,
        "ok_200": ok,
        "non_200": responses - ok,
        "errors": error_count,
        "error_types": "; ".join(f"{k}: {v}" for k, v in errors.items()) or "-",
        "success_rate_pct": ok / (responses + error_count) * 100 if responses + error_count else 0,
        "test_time_s": s["total"],
        "latency_avg_ms": ms(s["average"]),
        "latency_p50_ms": ms(lat.get("p50")),
        "latency_p95_ms": ms(lat.get("p95")),
        "latency_p99_ms": ms(lat.get("p99")),
        "latency_max_ms": ms(s["slowest"]),
        "response_size_bytes": s["sizePerRequest"],
        "total_data_mb": s["totalData"] / 1024 / 1024,
        "data_per_sec_mb": s["sizePerSec"] / 1024 / 1024,
        "server_peak_memory_mb": peak_mb,
        "server_avg_cpu_pct": avg_cpu,
        "server_peak_cpu_pct": peak_cpu,
        "db_avg_cpu_pct": db_avg_cpu,
        "redis_avg_cpu_pct": redis_avg_cpu,
        "cache_hit_rate_pct": hit_rate,
        "oom_killed": oom_killed,
    }


# (label, key, format)
ROWS = [
    ("Successful requests / second", "requests_per_sec", "{:,.0f}"),
    ("Attempts / second (incl. failed)", "attempts_per_sec", "{:,.0f}"),
    ("Total attempts", "total_requests", "{:,}"),
    ("Successful (200)", "ok_200", "{:,}"),
    ("Other HTTP status", "non_200", "{:,}"),
    ("Errors", "errors", "{:,}"),
    ("Success rate", "success_rate_pct", "{:.2f}%"),
    ("Test time", "test_time_s", "{:.2f} s"),
    ("Latency avg", "latency_avg_ms", "{:.2f} ms"),
    ("Latency p50", "latency_p50_ms", "{:.2f} ms"),
    ("Latency p95", "latency_p95_ms", "{:.2f} ms"),
    ("Latency p99", "latency_p99_ms", "{:.2f} ms"),
    ("Latency max", "latency_max_ms", "{:.2f} ms"),
    ("Response size", "response_size_bytes", "{} B"),
    ("Total data received", "total_data_mb", "{:.2f} MB"),
    ("Data / second", "data_per_sec_mb", "{:.2f} MB/s"),
    ("Server peak memory", "server_peak_memory_mb", "{:.1f} MB"),
    ("Server avg CPU", "server_avg_cpu_pct", "{:.0f}%"),
    ("Server peak CPU", "server_peak_cpu_pct", "{:.0f}%"),
    ("Postgres avg CPU", "db_avg_cpu_pct", "{:.0f}%"),
    ("Redis avg CPU", "redis_avg_cpu_pct", "{:.0f}%"),
    ("Cache hit rate", "cache_hit_rate_pct", "{:.1f}%"),
    ("Killed for exceeding memory limit", "oom_killed", "{}"),
]


def fmt(fmt_str, value):
    return "-" if value is None else fmt_str.format(value)


def markdown_table(results):
    lines = [
        "| Metric | " + " | ".join(r["backend"] for r in results) + " |",
        "|---|" + "---:|" * len(results),
    ]
    for label, key, f in ROWS:
        lines.append(f"| {label} | " + " | ".join(fmt(f, r[key]) for r in results) + " |")
    return "\n".join(lines)


def cap_mb(cap: str) -> float:
    units = {"k": 1 / 1024, "m": 1, "g": 1024}
    return float(cap[:-1]) * units.get(cap[-1].lower(), 1 / 1024 / 1024)


# (label, key, format) for the backend x memory-limit tables
MATRIX_ROWS = [
    ("Successful requests / second", "requests_per_sec", "{:,.0f}"),
    ("Success rate", "success_rate_pct", "{:.1f}%"),
    ("Latency p50", "latency_p50_ms", "{:,.1f} ms"),
    ("Latency p99", "latency_p99_ms", "{:,.1f} ms"),
    ("Server peak memory", "server_peak_memory_mb", "{:.0f} MB"),
    ("Cache hit rate", "cache_hit_rate_pct", "{:.1f}%"),
    ("Killed for exceeding memory limit", "oom_killed", "{}"),
]


def matrix(out: Path):
    """Summarizes a multi-limit run: one sub-directory per memory limit."""
    caps = sorted((d for d in out.iterdir() if (d / "config.json").exists()), key=lambda d: cap_mb(d.name))
    cells, rows = {}, []
    for d in caps:
        for b in BACKENDS:
            if (d / f"{b}.json").exists():
                cells[b, d.name] = r = summarize(d, b)
                rows.append({"memory_limit": d.name, **r})
            elif (d / f"{b}.failed").exists():
                cells[b, d.name] = (d / f"{b}.failed").read_text().strip()
                rows.append({"memory_limit": d.name, "backend": b, "oom_killed": cells[b, d.name]})
    backends = [b for b in BACKENDS if any((b, d.name) in cells for d in caps)]

    with open(out / "matrix.csv", "w", newline="") as f:
        fields = ["memory_limit"] + [k for k in rows[0] if k != "memory_limit"]
        writer = csv.DictWriter(f, fieldnames=fields, restval="")
        writer.writeheader()
        writer.writerows(rows)

    config = json.loads((caps[0] / "config.json").read_text())
    parts = [
        f"# GET {config.get('endpoint', '/health')} under memory limits\n",
        f"- **Load:** {config['users']:,} concurrent users, {config['duration']} per run, one backend at a time",
        f"- **Memory limits:** {', '.join(d.name for d in caps)} per backend container, swap off",
        f"- **Database:** Postgres in Docker, {config.get('db_pool_size', '?')} pooled connections per backend",
        f"- **{config['environment']}**; host {config['cpu']}, {config['cores']} cores",
    ]
    for label, key, f in MATRIX_ROWS:
        if key == "cache_hit_rate_pct" and not config.get("endpoint", "").endswith("/cached"):
            continue
        parts.append(f"\n## {label}\n")
        parts.append("| Backend | " + " | ".join(d.name for d in caps) + " |")
        parts.append("|---|" + "---:|" * len(caps))
        for b in backends:
            vals = []
            for d in caps:
                c = cells.get((b, d.name))
                if c is None:
                    vals.append("-")
                elif isinstance(c, str):
                    vals.append("not tested" if key != "oom_killed" else c)
                else:
                    vals.append(fmt(f, c[key]))
            parts.append(f"| {b} | " + " | ".join(vals) + " |")
    md = "\n".join(parts) + "\n"
    (out / "matrix.md").write_text(md)
    print(md)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("out", type=Path)
    parser.add_argument("--only", help="print a single backend's result without writing files")
    parser.add_argument("--matrix", action="store_true", help="summarize a multi-memory-limit run")
    args = parser.parse_args()

    if args.matrix:
        matrix(args.out)
        return

    if args.only:
        r = summarize(args.out, args.only)
        print(
            f"  {r['requests_per_sec']:,.0f} ok req/s | {r['total_requests']:,} attempts | "
            f"{r['errors']:,} errors | p50 {r['latency_p50_ms']:.1f} ms | "
            f"p99 {r['latency_p99_ms']:.1f} ms | {r['response_size_bytes']} B/response"
        )
        return

    results = [summarize(args.out, b) for b in BACKENDS if (args.out / f"{b}.json").exists()]
    config = json.loads((args.out / "config.json").read_text())

    with open(args.out / "summary.csv", "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(results[0].keys()))
        writer.writeheader()
        writer.writerows(results)

    winner = max(results, key=lambda r: r["requests_per_sec"])
    limit = (
        f"- **Memory limit:** {config['memory_limit']} per backend container, swap off; {config['environment']}\n"
        if "memory_limit" in config
        else ""
    )
    md = f"""# /health load test

- **Load:** {config['users']:,} concurrent users (keep-alive connections) on `GET {config.get('endpoint', '/health')}`, {config['duration']} per backend, run one at a time
- **Machine:** {config['cpu']}, {config['cores']} cores, {config['memory_gb']} GB RAM; load generator (oha {config['oha']}) on the same machine
{limit}- **Started:** {config['started_at']}
- **Highest throughput:** {winner['backend']} at {winner['requests_per_sec']:,.0f} req/s

{markdown_table(results)}

Errors by type: {"; ".join(f"{r['backend']}: {r['error_types']}" for r in results)}
"""
    (args.out / "summary.md").write_text(md)
    print(md)


if __name__ == "__main__":
    main()
