# ARCHITECTURE.md

## Overview

`docker_laravel` is a personal Docker-course follow-along repo. `master`'s 10 commits (04–13) map one-to-one to `Command.txt` lesson headers; each commit is one lesson. The Laravel app under `src/` is the course's "real project" example: a read-only `Post hasMany Comment` domain, exposed via GET routes only. Not a production application; not intended to be extended beyond the course.

## Stack

| Layer | Choice | Source |
|---|---|---|
| Framework | Laravel 10 | `src/composer.json` `laravel/framework ^10.10`, lock `v10.43.0` |
| PHP | ^8.1 | `php.dockerfile` `FROM php:8.3-fpm-alpine` |
| Database | MySQL 8.3.0 | `docker-compose.yml` `mysql` service, `laraveldb` |
| Web server | nginx | `nginx.dockerfile` `FROM nginx:stable-alpine`, `nginx/default.conf` |
| Frontend | Vite + Tailwind | `src/package.json` devDeps, `vite.config.js`, `tailwind.config.js` |
| Auth | Laravel Sanctum | `laravel/sanctum ^3.3`; `User` uses `HasApiTokens` |
| Testing | PHPUnit 10.5.10 | `src/phpunit.xml`, `tests/` |
| Container | Docker Compose v3.8 | `docker-compose.yml`, 9 services |
| Package mgmt | Composer / npm | `composer.lock`, `package-lock.json` |

## Module diagram

```mermaid
graph TD
    Browser[Browser / curl] -->|HTTP| Nginx[nginx:80]
    Nginx -->|fastcgi| Php[php:8.3-fpm (port 9000)]
    Php -->|PDO| Mysql[(mysql:8.3.0, laraveldb)]
    Php -->|views| Blade[resources/views/*.blade.php]
    Php -->|routes| Routes[src/routes/web.php, api.php]
    Routes -->|controllers| Ctrl[src/app/Http/Controllers/]
    Ctrl -->|models| Models[src/app/Models/ User, Post, Comment]
    Models -->|Eloquent| Mysql
    Composer[composer service] -->|install| Vendor[src/vendor]
    Npm[npm service] -->|build| Assets[public/build]
    Phpunit[phpunit service] -->|tests| Tests[tests/Unit, tests/Feature]
```

## Data models

| Model | Table | Relationships | Fillable |
|---|---|---|---|
| `User` | `users` | hasMany Post, hasMany Comment | name, email, password |
| `Post` | `posts` | belongsTo User, hasMany Comment | (guarded: none) |
| `Comment` | `comments` | belongsTo Post | (guarded: none) |

Migrations (`src/database/migrations/`): `users`, `password_reset_tokens`, `failed_jobs`, `personal_access_tokens`, `posts`, `comments`. `posts.user_id` and `comments.{user_id, post_id}` are plain integers — foreign key constraints are commented out in both migration files.

## API contracts

| Route | Method | Controller/action | Auth |
|---|---|---|---|
| `/` | GET | closure → `view('posts', ['posts' => Post::all()])` | none |
| `/posts` | GET | `PostController::index` → `Post::all()` | none |
| `/posts/{post}` | GET | `PostController::show` (route-model binding) | none |
| `/posts/{post}/comments` | GET | `CommentController::index` → `$post->comments` | none |
| `/posts/{post}/comments/{comment}` | GET | `CommentController::show` | none |
| `/api/user` | GET | closure → `$request->user()` | `auth:sanctum` |

Note: `api.php` applies `auth:sanctum` but `config/auth.php` defines only the `web` guard — no `sanctum`/`api` guard is configured, so the `/api/user` route throws "Authentication guard [sanctum] is not defined" when hit (P1 finding).

## Authentication

- Default guard: `web` (session driver, `users` eloquent provider).
- `config/sanctum.php`: stateful domains `localhost…`, guard `['web']`, token prefix empty.
- `User` model uses `HasApiTokens, HasFactory, Notifiable`; `password` and `remember_token` hidden; `password` cast `hashed`.
- Sanctum middleware group in `Http/Kernel.php` `api` group: `ThrottleRequests:api` + `SubstituteBindings` (EnsureFrontendRequestsAreStateful commented out).

## Database

- Default connection: `mysql` (env `DB_CONNECTION`, default `mysql`).
- `docker-compose.yml` mounts `./mysql:/var/lib/mysql` (host-persisted data dir) and exposes `4306:3306`; credentials `laravel/secret`, root `secret`.
- No foreign keys; no indexes beyond defaults; no transactions, no backup/recovery (course scope).

## Config review

| File | Setting | Assessment |
|---|---|---|
| `config/auth.php` | guards: web only | Missing `api`/`sanctum` guard used by `/api/user` |
| `config/hashing.php` | driver `bcrypt`, rounds env `BCRYPT_ROUNDS` default 12 | Standard, no SHA1 confusion |
| `config/cors.php` | `allowed_origins/methods/headers: ['*']` | Wide-open CORS (P2) |
| `config/session.php` | `secure: null`, `same_site: lax`, `http_only: true` | Secure flag not forced over HTTPS |
| `config/database.php` | default `mysql`, strict mode on | Standard |

## Testing

- Framework: PHPUnit 10.5.10 (lock) vs `^10.1` (require-dev) — aligned.
- `phpunit.xml`: Unit + Feature testsuites; testing env; DB/MAIL/QUEUE/CACHE drivers set (DB connection lines commented out → MySQL required).
- Tests: `tests/Unit/PostTest.php` (`RefreshDatabase`, creates 5 users w/ 1 post each, asserts user count only), `tests/Unit/ExampleTest.php`, `tests/Feature/ExampleTest.php`.
- No route/controller tests; `RefreshDatabase` without sqlite means tests need a live MySQL container (P1).
- Seeders use hardcoded IDs (`PostSeeder->forUser(3)`, `CommentFactory` ranges 1–20 / 1–3) — break on DB reset (P1).

## Security

- `src/.env.example` ships a real `APP_KEY` (not a placeholder) and `DB_PASSWORD=secret` (P0 — CLAUDE.md requires placeholders only).
- `docker-compose.yml` hardcodes `MYSQL_ROOT_PASSWORD=secret`, `MYSQL_PASSWORD=secret`.
- CORS allows all origins/methods/headers (P2).
- Session `secure` cookie unset (P2).
- Git history: 15 commits on master only, no secrets in commit messages.
- `.vscode/settings.json` committed (IDE artifact — Phase 4).
- No `.dockerignore`; no secret scanning in CI (no CI exists).
