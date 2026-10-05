# GET /users/random under memory limits

- **Load:** 4,000 concurrent users, 30s per run, one backend at a time
- **Memory limits:** 64m, 128m, 256m, 512m per backend container, swap off
- **Database:** Postgres in Docker, 20 pooled connections per backend
- **Docker VM: 8 CPUs, 7.7 GB RAM, 7.0.12-linuxkit kernel**; host Apple M3, 8 cores

## Successful requests / second

| Backend | 64m | 128m | 256m | 512m |
|---|---:|---:|---:|---:|
| python | 53 | 343 | 915 | 4,479 |
| go | 9 | 51 | 32,369 | 38,202 |
| node | 591 | 9,094 | 6,069 | 4,388 |
| cpp | 105,608 | 99,016 | 62,949 | 54,214 |
| rust | 4 | 1,050 | 23,517 | 21,494 |

## Success rate

| Backend | 64m | 128m | 256m | 512m |
|---|---:|---:|---:|---:|
| python | 2.7% | 15.3% | 100.0% | 100.0% |
| go | 0.3% | 1.9% | 100.0% | 100.0% |
| node | 29.5% | 100.0% | 100.0% | 99.8% |
| cpp | 100.0% | 100.0% | 100.0% | 100.0% |
| rust | 0.2% | 41.3% | 100.0% | 100.0% |

## Latency p50

| Backend | 64m | 128m | 256m | 512m |
|---|---:|---:|---:|---:|
| python | 145.3 ms | 305.4 ms | 3,556.8 ms | 851.2 ms |
| go | 58.4 ms | 112.8 ms | 112.7 ms | 96.3 ms |
| node | 125.9 ms | 430.3 ms | 547.0 ms | 748.9 ms |
| cpp | 29.3 ms | 29.0 ms | 47.2 ms | 55.7 ms |
| rust | 30.3 ms | 79.0 ms | 167.3 ms | 178.3 ms |

## Latency p99

| Backend | 64m | 128m | 256m | 512m |
|---|---:|---:|---:|---:|
| python | 316.5 ms | 1,625.2 ms | 15,742.3 ms | 2,096.2 ms |
| go | 85.2 ms | 149.0 ms | 309.0 ms | 226.3 ms |
| node | 1,526.2 ms | 1,173.8 ms | 5,744.8 ms | 10,421.0 ms |
| cpp | 173.3 ms | 208.8 ms | 332.1 ms | 335.6 ms |
| rust | 60.2 ms | 1,468.8 ms | 257.9 ms | 357.5 ms |

## Server peak memory

| Backend | 64m | 128m | 256m | 512m |
|---|---:|---:|---:|---:|
| python | - | 122 MB | 145 MB | 146 MB |
| go | - | - | 218 MB | 219 MB |
| node | 56 MB | 123 MB | 116 MB | 118 MB |
| cpp | 62 MB | 63 MB | 63 MB | 61 MB |
| rust | - | 128 MB | 180 MB | 170 MB |

## Killed for exceeding memory limit

| Backend | 64m | 128m | 256m | 512m |
|---|---:|---:|---:|---:|
| python | yes | yes | no | no |
| go | yes | yes | no | no |
| node | yes | no | no | no |
| cpp | no | no | no | no |
| rust | yes | yes | no | no |
