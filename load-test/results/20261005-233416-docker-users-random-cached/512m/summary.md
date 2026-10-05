# /health load test

- **Load:** 4,000 concurrent users (keep-alive connections) on `GET /users/random/cached`, 30s per backend, run one at a time
- **Machine:** Apple M3, 8 cores, 24 GB RAM; load generator (oha 1.16.0) on the same machine
- **Memory limit:** 512m per backend container, swap off; Docker VM: 8 CPUs, 7.7 GB RAM, 7.0.12-linuxkit kernel
- **Started:** 2026-10-05T18:16:18Z
- **Highest throughput:** rust at 118,186 req/s

| Metric | python | go | node | cpp | rust |
|---|---:|---:|---:|---:|---:|
| Successful requests / second | 8,104 | 61,048 | 8,299 | 91,724 | 118,186 |
| Attempts / second (incl. failed) | 8,104 | 61,048 | 8,378 | 91,724 | 118,186 |
| Total attempts | 246,976 | 1,835,798 | 335,481 | 2,757,520 | 3,553,935 |
| Successful (200) | 246,976 | 1,835,798 | 332,318 | 2,757,520 | 3,553,935 |
| Other HTTP status | 0 | 0 | 0 | 0 | 0 |
| Errors | 0 | 0 | 3,163 | 0 | 0 |
| Success rate | 100.00% | 100.00% | 99.06% | 100.00% | 100.00% |
| Test time | 30.48 s | 30.07 s | 40.04 s | 30.06 s | 30.07 s |
| Latency avg | 490.14 ms | 65.33 ms | 236.56 ms | 43.50 ms | 33.75 ms |
| Latency p50 | 412.24 ms | 62.14 ms | 127.04 ms | 41.26 ms | 32.15 ms |
| Latency p95 | 725.03 ms | 86.70 ms | 170.80 ms | 71.71 ms | 43.54 ms |
| Latency p99 | 9455.08 ms | 111.53 ms | 189.69 ms | 98.51 ms | 58.85 ms |
| Latency max | 9755.15 ms | 185.54 ms | 29861.78 ms | 180.65 ms | 4476.94 ms |
| Response size | 133 B | 133 B | 133 B | 133 B | 133 B |
| Total data received | 31.46 MB | 233.83 MB | 42.33 MB | 351.24 MB | 452.67 MB |
| Data / second | 1.03 MB/s | 7.78 MB/s | 1.06 MB/s | 11.68 MB/s | 15.05 MB/s |
| Server peak memory | 158.8 MB | 227.8 MB | 116.4 MB | 62.0 MB | 126.8 MB |
| Server avg CPU | 98% | 370% | 111% | 368% | 393% |
| Server peak CPU | 100% | 389% | 157% | 385% | 418% |
| Postgres avg CPU | 0% | 0% | 2% | 1% | 3% |
| Redis avg CPU | 11% | 68% | 2% | 88% | 21% |
| Cache hit rate | 100.0% | 100.0% | 100.0% | 100.0% | 100.0% |
| Killed for exceeding memory limit | no | no | no | no | no |

Errors by type: python: -; go: -; node: connection error: 499; timeout: 2664; cpp: -; rust: -
