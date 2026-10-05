# /health load test

- **Load:** 4,000 concurrent users (keep-alive connections) on `GET /users/random/cached`, 30s per backend, run one at a time
- **Machine:** Apple M3, 8 cores, 24 GB RAM; load generator (oha 1.16.0) on the same machine
- **Memory limit:** 128m per backend container, swap off; Docker VM: 8 CPUs, 7.7 GB RAM, 7.0.12-linuxkit kernel
- **Started:** 2026-10-05T18:08:17Z
- **Highest throughput:** cpp at 136,044 req/s

| Metric | python | go | node | cpp | rust |
|---|---:|---:|---:|---:|---:|
| Successful requests / second | 939 | 20 | 11,325 | 136,044 | 19,540 |
| Attempts / second (incl. failed) | 2,954 | 1,988 | 11,404 | 136,044 | 21,334 |
| Total attempts | 100,518 | 60,170 | 399,774 | 4,087,980 | 720,747 |
| Successful (200) | 31,936 | 616 | 396,991 | 4,087,980 | 660,141 |
| Other HTTP status | 0 | 0 | 0 | 0 | 0 |
| Errors | 68,582 | 59,554 | 2,783 | 0 | 60,606 |
| Success rate | 31.77% | 1.02% | 99.30% | 100.00% | 91.59% |
| Test time | 34.03 s | 30.27 s | 35.06 s | 30.05 s | 33.78 s |
| Latency avg | 8.80 ms | 56.07 ms | 203.26 ms | 29.33 ms | 20.21 ms |
| Latency p50 | 4.11 ms | 57.98 ms | 122.05 ms | 28.57 ms | 14.79 ms |
| Latency p95 | 5.15 ms | 76.83 ms | 156.63 ms | 45.58 ms | 27.69 ms |
| Latency p99 | 161.07 ms | 82.06 ms | 173.50 ms | 69.01 ms | 38.17 ms |
| Latency max | 1119.37 ms | 83.91 ms | 29957.63 ms | 211.17 ms | 2708.15 ms |
| Response size | 133 B | 133 B | 133 B | 133 B | 133 B |
| Total data received | 4.07 MB | 0.08 MB | 50.56 MB | 520.69 MB | 84.09 MB |
| Data / second | 0.12 MB/s | 0.00 MB/s | 1.44 MB/s | 17.33 MB/s | 2.49 MB/s |
| Server peak memory | 119.3 MB | - | 126.6 MB | 62.1 MB | 126.4 MB |
| Server avg CPU | 93% | - | 122% | 375% | 390% |
| Server peak CPU | 97% | - | 149% | 398% | 392% |
| Postgres avg CPU | 0% | 2% | 0% | 1% | 2% |
| Redis avg CPU | 3% | 2% | 2% | 84% | 3% |
| Cache hit rate | 100.0% | 100.0% | 100.0% | 100.0% | 100.0% |
| Killed for exceeding memory limit | yes | yes | no | no | yes |

Errors by type: python: Connection refused (os error 111): 39501; connection closed before message completed: 3011; connection error: 2070; timeout: 24000; go: Connection refused (os error 111): 28427; Connection reset by peer (os error 104): 27; connection closed before message completed: 3943; connection error: 3002; error writing a body to connection: 45; operation was canceled: 110; timeout: 24000; node: connection error: 267; timeout: 2516; cpp: -; rust: Connection refused (os error 111): 33017; Host is unreachable (os error 113): 58; connection closed before message completed: 3154; connection error: 885; timeout: 23492
