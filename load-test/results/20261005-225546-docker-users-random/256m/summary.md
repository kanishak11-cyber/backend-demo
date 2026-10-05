# /health load test

- **Load:** 4,000 concurrent users (keep-alive connections) on `GET /users/random`, 30s per backend, run one at a time
- **Machine:** Apple M3, 8 cores, 24 GB RAM; load generator (oha 1.16.0) on the same machine
- **Memory limit:** 256m per backend container, swap off; Docker VM: 8 CPUs, 7.7 GB RAM, 7.0.12-linuxkit kernel
- **Started:** 2026-10-05T17:33:35Z
- **Highest throughput:** cpp at 62,949 req/s

| Metric | python | go | node | cpp | rust |
|---|---:|---:|---:|---:|---:|
| Successful requests / second | 915 | 32,369 | 6,069 | 62,949 | 23,517 |
| Attempts / second (incl. failed) | 915 | 32,369 | 6,069 | 62,949 | 23,517 |
| Total attempts | 29,656 | 974,540 | 185,442 | 1,897,891 | 710,869 |
| Successful (200) | 29,656 | 974,540 | 185,442 | 1,897,891 | 710,869 |
| Other HTTP status | 0 | 0 | 0 | 0 | 0 |
| Errors | 0 | 0 | 0 | 0 | 0 |
| Success rate | 100.00% | 100.00% | 100.00% | 100.00% | 100.00% |
| Test time | 32.42 s | 30.11 s | 30.55 s | 30.15 s | 30.23 s |
| Latency avg | 4129.96 ms | 122.51 ms | 652.58 ms | 63.34 ms | 169.18 ms |
| Latency p50 | 3556.81 ms | 112.65 ms | 547.03 ms | 47.24 ms | 167.30 ms |
| Latency p95 | 9203.30 ms | 178.47 ms | 657.18 ms | 172.62 ms | 201.54 ms |
| Latency p99 | 15742.27 ms | 309.03 ms | 5744.81 ms | 332.11 ms | 257.85 ms |
| Latency max | 21675.02 ms | 852.92 ms | 29642.49 ms | 837.00 ms | 2393.85 ms |
| Response size | 133 B | 134 B | 133 B | 133 B | 133 B |
| Total data received | 3.78 MB | 125.06 MB | 23.62 MB | 241.75 MB | 90.55 MB |
| Data / second | 0.12 MB/s | 4.15 MB/s | 0.77 MB/s | 8.02 MB/s | 3.00 MB/s |
| Server peak memory | 145.2 MB | 218.5 MB | 116.1 MB | 62.7 MB | 179.6 MB |
| Server avg CPU | 100% | 284% | 162% | 290% | 250% |
| Server peak CPU | 133% | 321% | 169% | 311% | 275% |
| Postgres avg CPU | 43% | 230% | 34% | 319% | 241% |
| Killed for exceeding memory limit | no | no | no | no | no |

Errors by type: python: -; go: -; node: -; cpp: -; rust: -
