#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <ctime>
#include <iostream>
#include <memory>
#include <random>
#include <string>

#include <crow.h>
#include <hiredis/hiredis.h>
#include <libpq-fe.h>

namespace {

constexpr const char* kUserQuery = R"sql(
    SELECT id, name, email, age, city,
           to_char(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at
    FROM users
    WHERE id = $1)sql";

constexpr int kCacheTtlSeconds = 300;

const auto kStartTime = std::chrono::steady_clock::now();

std::string g_database_url;
std::string g_redis_host;
int g_redis_port = 6379;
int g_max_user_id = 0;

using Result = std::unique_ptr<PGresult, decltype(&PQclear)>;
using Reply = std::unique_ptr<redisReply, decltype(&freeReplyObject)>;

std::string getenv_or(const char* key, const char* fallback) {
  const char* value = std::getenv(key);
  return value && *value ? value : fallback;
}

// Splits "redis://host:port" into host and port.
void parse_redis_url(const std::string& url) {
  std::string rest = url.rfind("redis://", 0) == 0 ? url.substr(8) : url;
  const auto colon = rest.rfind(':');
  g_redis_host = rest.substr(0, colon);
  if (colon != std::string::npos) g_redis_port = std::atoi(rest.c_str() + colon + 1);
}

std::string utc_timestamp() {
  using namespace std::chrono;
  const auto now = system_clock::now();
  const std::time_t secs = system_clock::to_time_t(now);
  const auto micros = duration_cast<microseconds>(now.time_since_epoch()).count() % 1'000'000;

  std::tm tm{};
  gmtime_r(&secs, &tm);
  char buf[40];
  std::snprintf(buf, sizeof buf, "%04d-%02d-%02dT%02d:%02d:%02d.%06lldZ", tm.tm_year + 1900,
                tm.tm_mon + 1, tm.tm_mday, tm.tm_hour, tm.tm_min, tm.tm_sec,
                static_cast<long long>(micros));
  return buf;
}

// libpq connections are blocking and not thread-safe, so each Crow worker
// thread keeps its own connection with the user query prepared on it.
class ThreadConnection {
 public:
  ~ThreadConnection() {
    if (conn_) PQfinish(conn_);
  }

  PGconn* get() {
    if (conn_ && PQstatus(conn_) == CONNECTION_OK) return conn_;
    if (conn_) PQfinish(conn_);

    conn_ = PQconnectdb(g_database_url.c_str());
    if (PQstatus(conn_) == CONNECTION_OK) {
      Result prepared(PQprepare(conn_, "random_user", kUserQuery, 1, nullptr), &PQclear);
      if (PQresultStatus(prepared.get()) == PGRES_COMMAND_OK) return conn_;
    }
    CROW_LOG_ERROR << "database connection failed: " << PQerrorMessage(conn_);
    PQfinish(conn_);
    conn_ = nullptr;
    return nullptr;
  }

 private:
  PGconn* conn_ = nullptr;
};

// Same idea for Redis: one blocking hiredis connection per worker thread.
class ThreadRedis {
 public:
  ~ThreadRedis() { reset(); }

  redisContext* get() {
    if (ctx_ && !ctx_->err) return ctx_;
    reset();
    ctx_ = redisConnect(g_redis_host.c_str(), g_redis_port);
    if (ctx_ && !ctx_->err) return ctx_;
    CROW_LOG_ERROR << "redis connection failed: " << (ctx_ ? ctx_->errstr : "out of memory");
    reset();
    return nullptr;
  }

  void reset() {
    if (ctx_) redisFree(ctx_);
    ctx_ = nullptr;
  }

 private:
  redisContext* ctx_ = nullptr;
};

thread_local ThreadConnection t_db;
thread_local ThreadRedis t_redis;
thread_local std::mt19937 t_rng{std::random_device{}()};

crow::response json_response(int status, std::string body, const char* cache = nullptr) {
  crow::response res{status, std::move(body)};
  res.set_header("Content-Type", "application/json");
  if (cache) res.set_header("X-Cache", cache);
  return res;
}

std::string error_body(const char* detail) { return crow::json::wvalue({{"detail", detail}}).dump(); }

std::string pick_user_id() {
  std::uniform_int_distribution<int> pick(1, g_max_user_id);
  return std::to_string(pick(t_rng));
}

// Reads one user from Postgres into `body` as JSON. Returns the HTTP status.
int load_user(const std::string& id, std::string& body) {
  PGconn* conn = t_db.get();
  if (!conn) {
    body = error_body("database unavailable");
    return 503;
  }

  const char* params[] = {id.c_str()};
  Result res(PQexecPrepared(conn, "random_user", 1, params, nullptr, nullptr, 0), &PQclear);
  if (PQresultStatus(res.get()) != PGRES_TUPLES_OK) {
    CROW_LOG_ERROR << "query user " << id << ": " << PQerrorMessage(conn);
    body = error_body("database error");
    return 500;
  }
  if (PQntuples(res.get()) == 0) {
    body = error_body("user not found");
    return 404;
  }

  const PGresult* r = res.get();
  body = crow::json::wvalue({
                                {"id", std::atoi(PQgetvalue(r, 0, 0))},
                                {"name", PQgetvalue(r, 0, 1)},
                                {"email", PQgetvalue(r, 0, 2)},
                                {"age", std::atoi(PQgetvalue(r, 0, 3))},
                                {"city", PQgetvalue(r, 0, 4)},
                                {"created_at", PQgetvalue(r, 0, 5)},
                            })
             .dump();
  return 200;
}

int load_max_user_id() {
  PGconn* conn = PQconnectdb(g_database_url.c_str());
  int max_id = -1;
  if (PQstatus(conn) == CONNECTION_OK) {
    Result res(PQexec(conn, "SELECT coalesce(max(id), 0) FROM users"), &PQclear);
    if (PQresultStatus(res.get()) == PGRES_TUPLES_OK) max_id = std::atoi(PQgetvalue(res.get(), 0, 0));
  }
  if (max_id < 0) std::cerr << "count users: " << PQerrorMessage(conn);
  PQfinish(conn);
  return max_id;
}

}  // namespace

int main() {
  g_database_url = getenv_or("DATABASE_URL", "postgres://demo:demo@localhost:5434/demo");
  parse_redis_url(getenv_or("REDIS_URL", "redis://localhost:6379"));
  const int pool_size = std::atoi(getenv_or("DB_POOL_SIZE", "20").c_str());
  const auto port = static_cast<std::uint16_t>(std::atoi(getenv_or("PORT", "8081").c_str()));

  g_max_user_id = load_max_user_id();
  if (g_max_user_id < 0) return 1;

  crow::SimpleApp app;
  app.loglevel(crow::LogLevel::Warning);

  CROW_ROUTE(app, "/health").methods(crow::HTTPMethod::Get)([] {
    const std::chrono::duration<double> uptime = std::chrono::steady_clock::now() - kStartTime;
    crow::json::wvalue body({
        {"status", "ok"},
        {"service", "cpp-service"},
        {"uptime_seconds", uptime.count()},
        {"timestamp", utc_timestamp()},
    });
    return crow::response{body};
  });

  CROW_ROUTE(app, "/users/random").methods(crow::HTTPMethod::Get)([] {
    if (g_max_user_id == 0) return json_response(404, error_body("no users"));
    std::string body;
    const int status = load_user(pick_user_id(), body);
    return json_response(status, std::move(body));
  });

  // Same as /users/random, but checks Redis first and caches misses.
  CROW_ROUTE(app, "/users/random/cached").methods(crow::HTTPMethod::Get)([] {
    if (g_max_user_id == 0) return json_response(404, error_body("no users"));
    const std::string id = pick_user_id();
    const std::string key = "user:" + id;

    redisContext* redis = t_redis.get();
    if (redis) {
      Reply reply(static_cast<redisReply*>(redisCommand(redis, "GET %s", key.c_str())),
                  &freeReplyObject);
      if (!reply) {
        t_redis.reset();  // connection broke; reconnect on the next request
        redis = nullptr;
      } else if (reply->type == REDIS_REPLY_STRING) {
        return json_response(200, std::string(reply->str, reply->len), "HIT");
      }
    }

    std::string body;
    const int status = load_user(id, body);
    if (status != 200) return json_response(status, std::move(body));

    if (redis) {
      Reply set(static_cast<redisReply*>(redisCommand(redis, "SET %s %b EX %d", key.c_str(),
                                                      body.data(), body.size(), kCacheTtlSeconds)),
                &freeReplyObject);
      if (!set) t_redis.reset();
    }
    return json_response(200, std::move(body), "MISS");
  });

  std::cout << "cpp-service listening on :" << port << std::endl;
  // One worker thread per database connection, since each query blocks its thread.
  // Crow leaves Nagle's algorithm on by default; small JSON replies need it off,
  // as Go, Node, uvicorn and hyper already do.
  app.port(port).concurrency(pool_size).tcp_nodelay().run();
}
