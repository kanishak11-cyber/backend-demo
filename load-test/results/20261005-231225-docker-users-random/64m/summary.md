# /health load test

- **Load:** 4,000 concurrent users (keep-alive connections) on `GET /users/random`, 30s per backend, run one at a time
- **Machine:** Apple M3, 8 cores, 24 GB RAM; load generator (oha 1.16.0) on the same machine
- **Memory limit:** 64m per backend container, swap off; Docker VM: 8 CPUs, 7.7 GB RAM, 7.0.12-linuxkit kernel
- **Started:** 2026-10-05T17:42:29Z
- **Highest throughput:** cpp at 74,710 req/s

| Metric | cpp |
|---|---:|
| Successful requests / second | 74,710 |
| Attempts / second (incl. failed) | 74,710 |
| Total attempts | 2,246,306 |
| Successful (200) | 2,246,306 |
| Other HTTP status | 0 |
| Errors | 0 |
| Success rate | 100.00% |
| Test time | 30.07 s |
| Latency avg | 53.40 ms |
| Latency p50 | 40.76 ms |
| Latency p95 | 137.84 ms |
| Latency p99 | 249.79 ms |
| Latency max | 752.45 ms |
| Response size | 133 B |
| Total data received | 286.12 MB |
| Data / second | 9.52 MB/s |
| Server peak memory | 60.7 MB |
| Server avg CPU | 312% |
| Server peak CPU | 576% |
| Postgres avg CPU | 334% |
| Killed for exceeding memory limit | no |

Errors by type: cpp: -
