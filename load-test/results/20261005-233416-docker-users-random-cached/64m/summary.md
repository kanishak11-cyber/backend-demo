# /health load test

- **Load:** 4,000 concurrent users (keep-alive connections) on `GET /users/random/cached`, 30s per backend, run one at a time
- **Machine:** Apple M3, 8 cores, 24 GB RAM; load generator (oha 1.16.0) on the same machine
- **Memory limit:** 64m per backend container, swap off; Docker VM: 8 CPUs, 7.7 GB RAM, 7.0.12-linuxkit kernel
- **Started:** 2026-10-05T18:04:27Z
- **Highest throughput:** cpp at 144,337 req/s

| Metric | python | go | node | cpp | rust |
|---|---:|---:|---:|---:|---:|
| Successful requests / second | 0 | 8 | 30 | 144,337 | 401 |
| Attempts / second (incl. failed) | 2,201 | 1,803 | 2,453 | 144,337 | 2,255 |
| Total attempts | 66,677 | 62,888 | 74,384 | 4,336,500 | 68,307 |
| Successful (200) | 5 | 294 | 896 | 4,336,500 | 12,143 |
| Other HTTP status | 0 | 0 | 0 | 0 | 0 |
| Errors | 66,672 | 62,594 | 73,488 | 0 | 56,164 |
| Success rate | 0.01% | 0.47% | 1.20% | 100.00% | 17.78% |
| Test time | 30.29 s | 34.88 s | 30.32 s | 30.04 s | 30.29 s |
| Latency avg | 77.80 ms | 35.67 ms | 76.13 ms | 27.65 ms | 15.39 ms |
| Latency p50 | 76.27 ms | 34.12 ms | 76.31 ms | 26.79 ms | 10.69 ms |
| Latency p95 | 88.10 ms | 58.11 ms | 105.26 ms | 44.24 ms | 38.24 ms |
| Latency p99 | 88.10 ms | 62.44 ms | 106.12 ms | 57.27 ms | 59.94 ms |
| Latency max | 88.10 ms | 62.94 ms | 112.98 ms | 132.79 ms | 70.91 ms |
| Response size | 133 B | 133 B | 133 B | 133 B | 133 B |
| Total data received | 0.00 MB | 0.04 MB | 0.11 MB | 552.36 MB | 1.55 MB |
| Data / second | 0.00 MB/s | 0.00 MB/s | 0.00 MB/s | 18.38 MB/s | 0.05 MB/s |
| Server peak memory | - | - | - | 61.9 MB | - |
| Server avg CPU | - | - | - | 379% | - |
| Server peak CPU | - | - | - | 397% | - |
| Postgres avg CPU | 2% | 2% | 0% | 1% | 0% |
| Redis avg CPU | 2% | 2% | 1% | 86% | 2% |
| Cache hit rate | 100.0% | 100.0% | 100.0% | 100.0% | 100.0% |
| Killed for exceeding memory limit | yes | yes | yes | no | yes |

Errors by type: python: Connection refused (os error 111): 39324; connection closed before message completed: 719; connection error: 2629; timeout: 24000; go: Connection refused (os error 111): 32713; Host is unreachable (os error 113): 1; connection closed before message completed: 411; connection error: 5387; error writing a body to connection: 21; operation was canceled: 61; timeout: 24000; node: Connection refused (os error 111): 48066; connection closed before message completed: 216; connection error: 1206; timeout: 24000; cpp: -; rust: Connection refused (os error 111): 29794; connection closed before message completed: 1927; connection error: 468; timeout: 23975
