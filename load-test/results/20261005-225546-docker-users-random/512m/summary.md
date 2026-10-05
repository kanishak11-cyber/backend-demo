# /health load test

- **Load:** 4,000 concurrent users (keep-alive connections) on `GET /users/random`, 30s per backend, run one at a time
- **Machine:** Apple M3, 8 cores, 24 GB RAM; load generator (oha 1.16.0) on the same machine
- **Memory limit:** 512m per backend container, swap off; Docker VM: 8 CPUs, 7.7 GB RAM, 7.0.12-linuxkit kernel
- **Started:** 2026-10-05T17:37:28Z
- **Highest throughput:** cpp at 54,214 req/s

| Metric | python | go | node | cpp | rust |
|---|---:|---:|---:|---:|---:|
| Successful requests / second | 4,479 | 38,202 | 4,388 | 54,214 | 21,494 |
| Attempts / second (incl. failed) | 4,479 | 38,202 | 4,395 | 54,214 | 21,494 |
| Total attempts | 138,434 | 1,153,881 | 135,406 | 1,630,520 | 649,088 |
| Successful (200) | 138,434 | 1,153,881 | 135,187 | 1,630,520 | 649,088 |
| Other HTTP status | 0 | 0 | 0 | 0 | 0 |
| Errors | 0 | 0 | 219 | 0 | 0 |
| Success rate | 100.00% | 100.00% | 99.84% | 100.00% | 100.00% |
| Test time | 30.91 s | 30.20 s | 30.81 s | 30.08 s | 30.20 s |
| Latency avg | 878.73 ms | 104.11 ms | 888.26 ms | 73.58 ms | 185.20 ms |
| Latency p50 | 851.17 ms | 96.28 ms | 748.89 ms | 55.75 ms | 178.25 ms |
| Latency p95 | 1137.36 ms | 149.74 ms | 979.48 ms | 191.55 ms | 226.67 ms |
| Latency p99 | 2096.19 ms | 226.33 ms | 10421.04 ms | 335.65 ms | 357.48 ms |
| Latency max | 4190.93 ms | 401.07 ms | 18995.65 ms | 864.16 ms | 2482.15 ms |
| Response size | 133 B | 134 B | 133 B | 133 B | 133 B |
| Total data received | 17.63 MB | 148.08 MB | 17.22 MB | 207.69 MB | 82.67 MB |
| Data / second | 0.57 MB/s | 4.90 MB/s | 0.56 MB/s | 6.91 MB/s | 2.74 MB/s |
| Server peak memory | 145.8 MB | 218.9 MB | 118.3 MB | 61.3 MB | 170.4 MB |
| Server avg CPU | 93% | 324% | 163% | 305% | 239% |
| Server peak CPU | 96% | 357% | 185% | 392% | 269% |
| Postgres avg CPU | 41% | 246% | 35% | 355% | 240% |
| Killed for exceeding memory limit | no | no | no | no | no |

Errors by type: python: -; go: -; node: timeout: 219; cpp: -; rust: -
