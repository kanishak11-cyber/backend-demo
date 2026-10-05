# /health load test

- **Load:** 4,000 concurrent users (keep-alive connections) on `GET /users/random`, 30s per backend, run one at a time
- **Machine:** Apple M3, 8 cores, 24 GB RAM; load generator (oha 1.16.0) on the same machine
- **Memory limit:** 64m per backend container, swap off; Docker VM: 8 CPUs, 7.7 GB RAM, 7.0.12-linuxkit kernel
- **Started:** 2026-10-05T17:25:55Z
- **Highest throughput:** cpp at 105,608 req/s

| Metric | python | go | node | cpp | rust |
|---|---:|---:|---:|---:|---:|
| Successful requests / second | 53 | 9 | 591 | 105,608 | 4 |
| Attempts / second (incl. failed) | 1,918 | 2,522 | 2,002 | 105,608 | 1,854 |
| Total attempts | 58,566 | 76,601 | 64,210 | 3,173,212 | 56,146 |
| Successful (200) | 1,604 | 267 | 18,954 | 3,173,212 | 122 |
| Other HTTP status | 0 | 0 | 0 | 0 | 0 |
| Errors | 56,962 | 76,334 | 45,256 | 0 | 56,024 |
| Success rate | 2.74% | 0.35% | 29.52% | 100.00% | 0.22% |
| Test time | 30.53 s | 30.37 s | 32.07 s | 30.05 s | 30.28 s |
| Latency avg | 150.10 ms | 55.83 ms | 164.23 ms | 37.79 ms | 32.45 ms |
| Latency p50 | 145.29 ms | 58.40 ms | 125.86 ms | 29.26 ms | 30.26 ms |
| Latency p95 | 289.62 ms | 84.62 ms | 172.25 ms | 95.72 ms | 44.92 ms |
| Latency p99 | 316.48 ms | 85.18 ms | 1526.18 ms | 173.26 ms | 60.17 ms |
| Latency max | 325.65 ms | 87.34 ms | 1907.82 ms | 536.88 ms | 62.27 ms |
| Response size | 133 B | 134 B | 133 B | 133 B | 133 B |
| Total data received | 0.20 MB | 0.03 MB | 2.41 MB | 404.19 MB | 0.02 MB |
| Data / second | 0.01 MB/s | 0.00 MB/s | 0.08 MB/s | 13.45 MB/s | 0.00 MB/s |
| Server peak memory | - | - | 56.3 MB | 62.3 MB | - |
| Server avg CPU | - | - | 146% | 299% | - |
| Server peak CPU | - | - | 146% | 307% | - |
| Postgres avg CPU | 1% | 0% | 2% | 326% | 2% |
| Killed for exceeding memory limit | yes | yes | yes | no | yes |

Errors by type: python: Connection refused (os error 111): 29846; connection closed before message completed: 1063; connection error: 2037; error writing a body to connection: 16; timeout: 24000; go: Connection refused (os error 111): 47083; connection closed before message completed: 1977; connection error: 3167; operation was canceled: 107; timeout: 24000; node: Connection refused (os error 111): 21110; connection closed before message completed: 1744; connection error: 552; timeout: 21850; cpp: -; rust: Connection refused (os error 111): 30002; connection closed before message completed: 1869; connection error: 623; timeout: 23530
