# /health load test

- **Load:** 4,000 concurrent users (keep-alive connections) on `GET /users/random/cached`, 30s per backend, run one at a time
- **Machine:** Apple M3, 8 cores, 24 GB RAM; load generator (oha 1.16.0) on the same machine
- **Memory limit:** 256m per backend container, swap off; Docker VM: 8 CPUs, 7.7 GB RAM, 7.0.12-linuxkit kernel
- **Started:** 2026-10-05T18:12:22Z
- **Highest throughput:** rust at 117,369 req/s

| Metric | python | go | node | cpp | rust |
|---|---:|---:|---:|---:|---:|
| Successful requests / second | 7,548 | 56,848 | 6,916 | 83,078 | 117,369 |
| Attempts / second (incl. failed) | 7,548 | 56,848 | 7,005 | 83,078 | 117,369 |
| Total attempts | 229,044 | 1,711,516 | 299,577 | 2,497,974 | 3,528,807 |
| Successful (200) | 229,044 | 1,711,516 | 295,765 | 2,497,974 | 3,528,807 |
| Other HTTP status | 0 | 0 | 0 | 0 | 0 |
| Errors | 0 | 0 | 3,812 | 0 | 0 |
| Success rate | 100.00% | 100.00% | 98.73% | 100.00% | 100.00% |
| Test time | 30.35 s | 30.11 s | 42.76 s | 30.07 s | 30.07 s |
| Latency avg | 526.33 ms | 70.13 ms | 244.34 ms | 48.02 ms | 33.98 ms |
| Latency p50 | 442.53 ms | 66.68 ms | 120.52 ms | 45.08 ms | 31.87 ms |
| Latency p95 | 995.82 ms | 90.67 ms | 192.44 ms | 78.75 ms | 43.25 ms |
| Latency p99 | 5469.50 ms | 127.93 ms | 323.85 ms | 113.96 ms | 58.23 ms |
| Latency max | 8190.42 ms | 187.74 ms | 29897.37 ms | 210.80 ms | 7669.74 ms |
| Response size | 133 B | 133 B | 133 B | 133 B | 133 B |
| Total data received | 29.17 MB | 218.01 MB | 37.67 MB | 318.17 MB | 449.47 MB |
| Data / second | 0.96 MB/s | 7.24 MB/s | 0.88 MB/s | 10.58 MB/s | 14.95 MB/s |
| Server peak memory | 158.6 MB | 226.0 MB | 115.8 MB | 62.0 MB | 128.2 MB |
| Server avg CPU | 97% | 379% | 104% | 354% | 391% |
| Server peak CPU | 100% | 392% | 158% | 376% | 419% |
| Postgres avg CPU | 1% | 1% | 2% | 1% | 2% |
| Redis avg CPU | 10% | 67% | 1% | 85% | 18% |
| Cache hit rate | 100.0% | 100.0% | 100.0% | 100.0% | 100.0% |
| Killed for exceeding memory limit | no | no | no | no | no |

Errors by type: python: -; go: -; node: connection error: 613; timeout: 3199; cpp: -; rust: -
