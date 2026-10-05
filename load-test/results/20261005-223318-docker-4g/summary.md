# /health load test

- **Load:** 4,000 concurrent users (keep-alive connections) on `GET /health`, 30s per backend, run one at a time
- **Machine:** Apple M3, 8 cores, 24 GB RAM; load generator (oha 1.16.0) on the same machine
- **Memory limit:** 4g per backend container, swap off; Docker VM: 8 CPUs, 7.7 GB RAM, 7.0.12-linuxkit kernel
- **Started:** 2026-10-05T17:03:26Z
- **Highest throughput:** cpp at 269,725 req/s

| Metric | python | go | node | cpp | rust |
|---|---:|---:|---:|---:|---:|
| Successful requests / second | 7,016 | 235,129 | 13,172 | 269,725 | 247,393 |
| Attempts / second (incl. failed) | 7,016 | 235,129 | 13,272 | 269,725 | 247,393 |
| Total attempts | 213,000 | 7,063,321 | 564,981 | 8,101,910 | 7,432,035 |
| Successful (200) | 213,000 | 7,063,321 | 560,697 | 8,101,910 | 7,432,035 |
| Other HTTP status | 0 | 0 | 0 | 0 | 0 |
| Errors | 0 | 0 | 4,284 | 0 | 0 |
| Success rate | 100.00% | 100.00% | 99.24% | 100.00% | 100.00% |
| Test time | 30.36 s | 30.04 s | 42.57 s | 30.04 s | 30.04 s |
| Latency avg | 565.92 ms | 16.98 ms | 124.02 ms | 14.80 ms | 16.13 ms |
| Latency p50 | 524.34 ms | 16.01 ms | 65.75 ms | 13.66 ms | 11.92 ms |
| Latency p95 | 873.23 ms | 38.05 ms | 82.48 ms | 28.85 ms | 37.45 ms |
| Latency p99 | 1787.84 ms | 76.22 ms | 131.26 ms | 39.76 ms | 48.55 ms |
| Latency max | 5893.96 ms | 352.92 ms | 28837.86 ms | 127.22 ms | 4413.76 ms |
| Response size | 112 B | 113 B | 102 B | 115 B | 111 B |
| Total data received | 22.93 MB | 766.82 MB | 54.96 MB | 889.82 MB | 792.80 MB |
| Data / second | 0.76 MB/s | 25.53 MB/s | 1.29 MB/s | 29.62 MB/s | 26.39 MB/s |
| Server peak memory | 153.1 MB | 177.0 MB | 175.0 MB | 59.1 MB | 122.5 MB |
| Server avg CPU | 97% | 397% | 83% | 398% | 391% |
| Server peak CPU | 100% | 441% | 116% | 450% | 410% |
| Postgres avg CPU | - | - | - | - | - |
| Killed for exceeding memory limit | no | no | no | no | no |

Errors by type: python: -; go: -; node: connection error: 658; timeout: 3626; cpp: -; rust: -
