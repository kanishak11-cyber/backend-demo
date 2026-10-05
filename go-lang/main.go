package main

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"math/rand/v2"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
)

const userQuery = `
	SELECT id, name, email, age, city,
	       to_char(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at
	FROM users
	WHERE id = $1`

const cacheTTL = 300 * time.Second

var startTime = time.Now()

type healthResponse struct {
	Status        string  `json:"status"`
	Service       string  `json:"service"`
	UptimeSeconds float64 `json:"uptime_seconds"`
	Timestamp     string  `json:"timestamp"`
}

type user struct {
	ID        int32  `json:"id"`
	Name      string `json:"name"`
	Email     string `json:"email"`
	Age       int32  `json:"age"`
	City      string `json:"city"`
	CreatedAt string `json:"created_at"`
}

type server struct {
	pool      *pgxpool.Pool
	cache     *redis.Client
	maxUserID int32
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func (s *server) health(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, healthResponse{
		Status:        "ok",
		Service:       "go-service",
		UptimeSeconds: time.Since(startTime).Seconds(),
		Timestamp:     time.Now().UTC().Format(time.RFC3339Nano),
	})
}

// loadUser reads one user from Postgres. On failure it writes the error response
// and returns ok=false.
func (s *server) loadUser(w http.ResponseWriter, r *http.Request, id int32) (u user, ok bool) {
	err := s.pool.QueryRow(r.Context(), userQuery, id).
		Scan(&u.ID, &u.Name, &u.Email, &u.Age, &u.City, &u.CreatedAt)
	switch {
	case errors.Is(err, pgx.ErrNoRows):
		writeJSON(w, http.StatusNotFound, map[string]string{"detail": "user not found"})
		return u, false
	case err != nil:
		log.Printf("query user %d: %v", id, err)
		writeJSON(w, http.StatusInternalServerError, map[string]string{"detail": "database error"})
		return u, false
	}
	return u, true
}

func (s *server) pickUserID(w http.ResponseWriter) (int32, bool) {
	if s.maxUserID == 0 {
		writeJSON(w, http.StatusNotFound, map[string]string{"detail": "no users"})
		return 0, false
	}
	return rand.Int32N(s.maxUserID) + 1, true
}

func (s *server) randomUser(w http.ResponseWriter, r *http.Request) {
	id, ok := s.pickUserID(w)
	if !ok {
		return
	}
	if u, ok := s.loadUser(w, r, id); ok {
		writeJSON(w, http.StatusOK, u)
	}
}

// randomUserCached is randomUser with Redis in front: hits skip Postgres,
// misses are read from Postgres and cached.
func (s *server) randomUserCached(w http.ResponseWriter, r *http.Request) {
	id, ok := s.pickUserID(w)
	if !ok {
		return
	}
	key := "user:" + strconv.Itoa(int(id))

	cached, err := s.cache.Get(r.Context(), key).Bytes()
	if err == nil {
		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("X-Cache", "HIT")
		w.Write(cached)
		return
	}
	if !errors.Is(err, redis.Nil) {
		log.Printf("cache get %s: %v", key, err)
	}

	u, ok := s.loadUser(w, r, id)
	if !ok {
		return
	}
	body, err := json.Marshal(u)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"detail": "encode error"})
		return
	}
	if err := s.cache.Set(r.Context(), key, body, cacheTTL).Err(); err != nil {
		log.Printf("cache set %s: %v", key, err)
	}
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("X-Cache", "MISS")
	w.Write(body)
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func getenvInt(key string, fallback int) int {
	n, err := strconv.Atoi(getenv(key, strconv.Itoa(fallback)))
	if err != nil {
		log.Fatalf("invalid %s: %v", key, err)
	}
	return n
}

func main() {
	port := getenv("PORT", "8080")
	poolSize := getenvInt("DB_POOL_SIZE", 20)

	cfg, err := pgxpool.ParseConfig(getenv("DATABASE_URL", "postgres://demo:demo@localhost:5434/demo"))
	if err != nil {
		log.Fatalf("invalid DATABASE_URL: %v", err)
	}
	cfg.MaxConns = int32(poolSize)
	cfg.MinConns = int32(poolSize)

	ctx := context.Background()
	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		log.Fatalf("connect to database: %v", err)
	}
	defer pool.Close()

	redisOpts, err := redis.ParseURL(getenv("REDIS_URL", "redis://localhost:6379"))
	if err != nil {
		log.Fatalf("invalid REDIS_URL: %v", err)
	}
	redisOpts.PoolSize = getenvInt("REDIS_POOL_SIZE", 20)
	cache := redis.NewClient(redisOpts)
	defer cache.Close()
	if err := cache.Ping(ctx).Err(); err != nil {
		log.Fatalf("connect to redis: %v", err)
	}

	s := &server{pool: pool, cache: cache}
	if err := pool.QueryRow(ctx, "SELECT coalesce(max(id), 0) FROM users").Scan(&s.maxUserID); err != nil {
		log.Fatalf("count users: %v", err)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", s.health)
	mux.HandleFunc("GET /users/random", s.randomUser)
	mux.HandleFunc("GET /users/random/cached", s.randomUserCached)

	log.Printf("go-service listening on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, mux))
}
