# /health load test

- **Load:** 4,000 concurrent users (keep-alive connections) on `GET /users/random`, 30s per backend, run one at a time
- **Machine:** Apple M3, 8 cores, 24 GB RAM; load generator (oha 1.16.0) on the same machine
- **Memory limit:** 128m per backend container, swap off; Docker VM: 8 CPUs, 7.7 GB RAM, 7.0.12-linuxkit kernel
- **Started:** 2026-10-05T17:29:40Z
- **Highest throughput:** cpp at 99,016 req/s

| Metric | python | go | node | cpp | rust |
|---|---:|---:|---:|---:|---:|
| Successful requests / second | 343 | 51 | 9,094 | 99,016 | 1,050 |
| Attempts / second (incl. failed) | 2,241 | 2,705 | 9,094 | 99,016 | 2,545 |
| Total attempts | 71,552 | 82,443 | 276,426 | 2,978,662 | 89,114 |
| Successful (200) | 10,940 | 1,568 | 276,426 | 2,978,662 | 36,774 |
| Other HTTP status | 0 | 0 | 0 | 0 | 0 |
| Errors | 60,612 | 80,875 | 0 | 0 | 52,340 |
| Success rate | 15.29% | 1.90% | 100.00% | 100.00% | 41.27% |
| Test time | 31.93 s | 30.48 s | 30.40 s | 30.08 s | 35.01 s |
| Latency avg | 446.45 ms | 111.33 ms | 436.46 ms | 40.29 ms | 162.91 ms |
| Latency p50 | 305.43 ms | 112.81 ms | 430.28 ms | 29.04 ms | 79.01 ms |
| Latency p95 | 1273.38 ms | 135.06 ms | 479.35 ms | 111.10 ms | 284.72 ms |
| Latency p99 | 1625.19 ms | 149.01 ms | 1173.80 ms | 208.84 ms | 1468.80 ms |
| Latency max | 1686.33 ms | 153.31 ms | 8231.76 ms | 731.96 ms | 1514.89 ms |
| Response size | 133 B | 134 B | 133 B | 133 B | 133 B |
| Total data received | 1.39 MB | 0.20 MB | 35.21 MB | 379.39 MB | 4.68 MB |
| Data / second | 0.04 MB/s | 0.01 MB/s | 1.16 MB/s | 12.61 MB/s | 0.13 MB/s |
| Server peak memory | 121.6 MB | - | 122.6 MB | 62.5 MB | 127.9 MB |
| Server avg CPU | 94% | - | 160% | 298% | 214% |
| Server peak CPU | 94% | - | 164% | 310% | 214% |
| Postgres avg CPU | 2% | 2% | 33% | 325% | 19% |
| Killed for exceeding memory limit | yes | yes | no | no | yes |

Errors by type: python: Connection refused (os error 111): 31217; connection closed before message completed: 3426; connection error: 1945; error writing a body to connection: 12; operation was canceled: 17; timeout: 23995; go: Connection refused (os error 111): 49747; Host is unreachable (os error 113): 56; connection closed before message completed: 3991; connection error: 2890; error writing a body to connection: 39; operation was canceled: 208; timeout: 23944; node: -; cpp: -; rust: Connection refused (os error 111): 26100; connection closed before message completed: 3531; connection error: 160; timeout: 22549
