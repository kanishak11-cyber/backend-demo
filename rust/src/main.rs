use std::{env, time::Instant};

use axum::{
    Json, Router,
    extract::State,
    http::{HeaderName, StatusCode, header},
    response::{IntoResponse, Response},
    routing::get,
};
use chrono::{SecondsFormat, Utc};
use redis::{AsyncCommands, aio::ConnectionManager};
use serde::Serialize;
use serde_json::json;
use sqlx::{FromRow, PgPool, postgres::PgPoolOptions};

const USER_QUERY: &str = r#"
    SELECT id, name, email, age, city,
           to_char(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at
    FROM users
    WHERE id = $1"#;

const CACHE_TTL_SECONDS: u64 = 300;
const X_CACHE: HeaderName = HeaderName::from_static("x-cache");

#[derive(Clone)]
struct AppState {
    started: Instant,
    pool: PgPool,
    // One multiplexed connection; clones share it and pipeline commands.
    cache: ConnectionManager,
    max_user_id: i32,
}

#[derive(Serialize)]
struct HealthResponse {
    status: &'static str,
    service: &'static str,
    uptime_seconds: f64,
    timestamp: String,
}

#[derive(Serialize, FromRow)]
struct User {
    id: i32,
    name: String,
    email: String,
    age: i32,
    city: String,
    created_at: String,
}

fn error(status: StatusCode, detail: &str) -> Response {
    (status, Json(json!({ "detail": detail }))).into_response()
}

fn cached_json(body: String, cache: &'static str) -> Response {
    ([(header::CONTENT_TYPE, "application/json"), (X_CACHE, cache)], body).into_response()
}

async fn health(State(state): State<AppState>) -> Json<HealthResponse> {
    Json(HealthResponse {
        status: "ok",
        service: "rust-service",
        uptime_seconds: state.started.elapsed().as_secs_f64(),
        timestamp: Utc::now().to_rfc3339_opts(SecondsFormat::Micros, true),
    })
}

/// Reads one user from Postgres, or returns the error response to send.
async fn load_user(state: &AppState, id: i32) -> Result<User, Response> {
    match sqlx::query_as::<_, User>(USER_QUERY)
        .bind(id)
        .fetch_optional(&state.pool)
        .await
    {
        Ok(Some(user)) => Ok(user),
        Ok(None) => Err(error(StatusCode::NOT_FOUND, "user not found")),
        Err(err) => {
            eprintln!("query user {id}: {err}");
            Err(error(StatusCode::INTERNAL_SERVER_ERROR, "database error"))
        }
    }
}

async fn random_user(State(state): State<AppState>) -> Response {
    if state.max_user_id == 0 {
        return error(StatusCode::NOT_FOUND, "no users");
    }
    let id = rand::random_range(1..=state.max_user_id);
    match load_user(&state, id).await {
        Ok(user) => Json(user).into_response(),
        Err(response) => response,
    }
}

/// Same as random_user, but checks Redis first and caches misses.
async fn random_user_cached(State(state): State<AppState>) -> Response {
    if state.max_user_id == 0 {
        return error(StatusCode::NOT_FOUND, "no users");
    }
    let id = rand::random_range(1..=state.max_user_id);
    let key = format!("user:{id}");
    let mut cache = state.cache.clone();

    match cache.get::<_, Option<String>>(&key).await {
        Ok(Some(body)) => return cached_json(body, "HIT"),
        Ok(None) => {}
        Err(err) => eprintln!("cache get {key}: {err}"),
    }

    let user = match load_user(&state, id).await {
        Ok(user) => user,
        Err(response) => return response,
    };
    let body = serde_json::to_string(&user).expect("user serializes");
    if let Err(err) = cache.set_ex::<_, _, ()>(&key, &body, CACHE_TTL_SECONDS).await {
        eprintln!("cache set {key}: {err}");
    }
    cached_json(body, "MISS")
}

#[tokio::main]
async fn main() {
    let port: u16 = env::var("PORT")
        .ok()
        .and_then(|p| p.parse().ok())
        .unwrap_or(8082);
    let pool_size: u32 = env::var("DB_POOL_SIZE")
        .ok()
        .and_then(|p| p.parse().ok())
        .unwrap_or(20);
    let database_url = env::var("DATABASE_URL")
        .unwrap_or_else(|_| "postgres://demo:demo@localhost:5434/demo".to_string());
    let redis_url = env::var("REDIS_URL").unwrap_or_else(|_| "redis://localhost:6379".to_string());

    let pool = PgPoolOptions::new()
        .max_connections(pool_size)
        .min_connections(pool_size)
        .connect(&database_url)
        .await
        .expect("failed to connect to database");
    let max_user_id: i32 = sqlx::query_scalar("SELECT coalesce(max(id), 0) FROM users")
        .fetch_one(&pool)
        .await
        .expect("failed to count users");

    let redis_client = redis::Client::open(redis_url).expect("invalid REDIS_URL");
    let cache = ConnectionManager::new(redis_client)
        .await
        .expect("failed to connect to redis");

    let app = Router::new()
        .route("/health", get(health))
        .route("/users/random", get(random_user))
        .route("/users/random/cached", get(random_user_cached))
        .with_state(AppState { started: Instant::now(), pool, cache, max_user_id });

    let listener = tokio::net::TcpListener::bind(("0.0.0.0", port))
        .await
        .expect("failed to bind port");
    println!("rust-service listening on :{port}");
    axum::serve(listener, app).await.expect("server error");
}
