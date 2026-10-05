# GET /users/random/cached under memory limits

- **Load:** 4,000 concurrent users, 30s per run, one backend at a time
- **Memory limits:** 64m, 128m, 256m, 512m per backend container, swap off
- **Database:** Postgres in Docker, 20 pooled connections per backend
- **Docker VM: 8 CPUs, 7.7 GB RAM, 7.0.12-linuxkit kernel**; host Apple M3, 8 cores

## Successful requests / second

| Backend | 64m | 128m | 256m | 512m |
|---|---:|---:|---:|---:|
| python | 0 | 939 | 7,548 | 8,104 |
| go | 8 | 20 | 56,848 | 61,048 |
| node | 30 | 11,325 | 6,916 | 8,299 |
| cpp | 144,337 | 136,044 | 83,078 | 91,724 |
| rust | 401 | 19,540 | 117,369 | 118,186 |

## Success rate

| Backend | 64m | 128m | 256m | 512m |
|---|---:|---:|---:|---:|
| python | 0.0% | 31.8% | 100.0% | 100.0% |
| go | 0.5% | 1.0% | 100.0% | 100.0% |
| node | 1.2% | 99.3% | 98.7% | 99.1% |
| cpp | 100.0% | 100.0% | 100.0% | 100.0% |
| rust | 17.8% | 91.6% | 100.0% | 100.0% |

## Latency p50

| Backend | 64m | 128m | 256m | 512m |
|---|---:|---:|---:|---:|
| python | 76.3 ms | 4.1 ms | 442.5 ms | 412.2 ms |
| go | 34.1 ms | 58.0 ms | 66.7 ms | 62.1 ms |
| node | 76.3 ms | 122.0 ms | 120.5 ms | 127.0 ms |
| cpp | 26.8 ms | 28.6 ms | 45.1 ms | 41.3 ms |
| rust | 10.7 ms | 14.8 ms | 31.9 ms | 32.2 ms |

## Latency p99

| Backend | 64m | 128m | 256m | 512m |
|---|---:|---:|---:|---:|
| python | 88.1 ms | 161.1 ms | 5,469.5 ms | 9,455.1 ms |
| go | 62.4 ms | 82.1 ms | 127.9 ms | 111.5 ms |
| node | 106.1 ms | 173.5 ms | 323.8 ms | 189.7 ms |
| cpp | 57.3 ms | 69.0 ms | 114.0 ms | 98.5 ms |
| rust | 59.9 ms | 38.2 ms | 58.2 ms | 58.9 ms |

## Server peak memory

| Backend | 64m | 128m | 256m | 512m |
|---|---:|---:|---:|---:|
| python | - | 119 MB | 159 MB | 159 MB |
| go | - | - | 226 MB | 228 MB |
| node | - | 127 MB | 116 MB | 116 MB |
| cpp | 62 MB | 62 MB | 62 MB | 62 MB |
| rust | - | 126 MB | 128 MB | 127 MB |

## Cache hit rate

| Backend | 64m | 128m | 256m | 512m |
|---|---:|---:|---:|---:|
| python | 100.0% | 100.0% | 100.0% | 100.0% |
| go | 100.0% | 100.0% | 100.0% | 100.0% |
| node | 100.0% | 100.0% | 100.0% | 100.0% |
| cpp | 100.0% | 100.0% | 100.0% | 100.0% |
| rust | 100.0% | 100.0% | 100.0% | 100.0% |

## Killed for exceeding memory limit

| Backend | 64m | 128m | 256m | 512m |
|---|---:|---:|---:|---:|
| python | yes | yes | no | no |
| go | yes | yes | no | no |
| node | yes | no | no | no |
| cpp | no | no | no | no |
| rust | yes | yes | no | no |
