# /health load test

- **Load:** 4,000 concurrent users (keep-alive connections) on `GET /users/random`, 30s per backend, run one at a time
- **Machine:** Apple M3, 8 cores, 24 GB RAM; load generator (oha 1.16.0) on the same machine
- **Memory limit:** 64m per backend container, swap off; Docker VM: 8 CPUs, 7.7 GB RAM, 7.0.12-linuxkit kernel
- **Started:** 2026-10-05T17:48:19Z
- **Highest throughput:** cpp at 92,789 req/s

| Metric | cpp |
|---|---:|
| Successful requests / second | 92,789 |
| Attempts / second (incl. failed) | 92,789 |
| Total attempts | 2,793,204 |
| Successful (200) | 2,793,204 |
| Other HTTP status | 0 |
| Errors | 0 |
| Success rate | 100.00% |
| Test time | 30.10 s |
| Latency avg | 43.00 ms |
| Latency p50 | 33.94 ms |
| Latency p95 | 108.36 ms |
| Latency p99 | 186.11 ms |
| Latency max | 575.35 ms |
| Response size | 133 B |
| Total data received | 355.78 MB |
| Data / second | 11.82 MB/s |
| Server peak memory | 62.6 MB |
| Server avg CPU | 278% |
| Server peak CPU | 308% |
| Postgres avg CPU | 317% |
| Killed for exceeding memory limit | no |

Errors by type: cpp: -
