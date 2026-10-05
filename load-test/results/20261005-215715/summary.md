# /health load test

- **Load:** 4,000 concurrent users (keep-alive connections) on `GET /health`, 30s per backend, run one at a time
- **Machine:** Apple M3, 8 cores, 24 GB RAM; load generator (oha 1.16.0) on the same machine
- **Started:** 2026-10-05T16:27:15Z
- **Highest throughput:** go at 176,102 req/s

| Metric | python | go | node |
|---|---:|---:|---:|
| Successful requests / second | 8,000 | 176,102 | 18,125 |
| Attempts / second (incl. failed) | 19,184 | 176,178 | 57,741 |
| Total attempts | 579,660 | 5,290,734 | 1,742,194 |
| Successful (200) | 241,724 | 5,288,440 | 546,887 |
| Other HTTP status | 0 | 0 | 0 |
| Errors | 337,936 | 2,294 | 1,195,307 |
| Success rate | 41.70% | 99.96% | 31.39% |
| Test time | 30.22 s | 30.03 s | 30.17 s |
| Latency avg | 445.25 ms | 22.67 ms | 123.98 ms |
| Latency p50 | 429.10 ms | 21.33 ms | 118.22 ms |
| Latency p95 | 727.72 ms | 39.84 ms | 181.52 ms |
| Latency p99 | 792.40 ms | 66.28 ms | 266.36 ms |
| Latency max | 1284.09 ms | 258.84 ms | 9549.79 ms |
| Response size | 112 B | 110 B | 102 B |
| Total data received | 25.99 MB | 557.49 MB | 53.58 MB |
| Data / second | 0.86 MB/s | 18.56 MB/s | 1.78 MB/s |
| Server peak memory | 158.2 MB | 148.0 MB | 210.7 MB |
| Server avg CPU | 99% | 333% | 104% |
| Server peak CPU | 104% | 359% | 114% |
| Postgres avg CPU | - | - | - |
| Killed for exceeding memory limit | - | - | - |

Errors by type: python: Connection reset by peer (os error 54): 40646; Invalid argument (os error 22): 50; connection error: 295487; error writing a body to connection: 1161; operation was canceled: 592; go: Connection reset by peer (os error 54): 1256; connection error: 966; error writing a body to connection: 17; operation was canceled: 55; node: Connection reset by peer (os error 54): 30141; connection error: 1164570; error writing a body to connection: 259; operation was canceled: 337
