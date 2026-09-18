# docker_laravel

A personal follow-along of a Docker course, built around a minimal Laravel
app used purely as the course's "real project" example. This is Docker
learning material, not a Laravel application meant to be extended.

## What this actually is

`master`'s 10 commits (`04` through `13`) map one-to-one to `Command.txt`'s
lesson headers — this is a course repo where each commit is one lesson:

| Lesson | Commit | What it added |
|---|---|---|
| 04 | Setting up Apache | `apache.dockerfile` (superseded by nginx, see below) |
| 05 | Setting up PHP | `php.dockerfile` |
| 06 | Setting up MySQL | `mysql` service in `docker-compose.yml` |
| 07 | Installing and using Composer | `composer` service, `laravel/laravel` scaffolded into `src/` |
| 08 | Setting up our new Laravel app | initial Laravel skeleton |
| 09 | Setting up and using the Artisan service | `artisan` service (`entrypoint: php artisan`) |
| 10 | Setting up and using the npm service | `npm`/`npx` services, Vite/Tailwind wiring |
| 11 | Building a simple test application | `Post`/`Comment` models, controllers, migrations, seeders |
| 12 | Creating and running tests with PHPUnit | `phpunit` service, `tests/Unit/PostTest.php` |
| 13 | Improving local Docker performance | `:delegated` volume mounts, Tailwind view, final `web.php` routes |

`Command.txt` is the course's own command cheat-sheet, kept verbatim as a
lesson-by-lesson reference — not a script meant to be run as a whole.

## Stack

- **Docker Compose** (`docker-compose.yml`) — one network (`laravel`), services:
  - `nginx` — active web server (build: `nginx.dockerfile`), ports 80/443/5173
  - `apache` — **commented out** in `docker-compose.yml`; `apache.dockerfile`
    is left over from lesson 04, before the course switched to nginx
  - `php` — `php:8.3-fpm-alpine` + `pdo_mysql`
  - `composer`, `artisan`, `phpunit`, `npm`, `npx` — one-shot task runners,
    each mounting `./src` and exec'ing straight into the named tool
  - `mysql` — `mysql:8.3.0`, database `laraveldb`
- **Laravel 10** (`src/`) — `laravel/framework ^10.10`, PHP `^8.1`
- **Vite + Tailwind CSS** for the one view lesson 13 added

## The "application" (lesson 11-13)

A `Post hasMany Comment` / `Comment belongsTo Post` pair, exposed read-only:

```
GET /posts                          PostController::index    -> Post::all()
GET /posts/{post}                   PostController::show
GET /posts/{post}/comments          CommentController::index
GET /posts/{post}/comments/{comment} CommentController::show
GET /                               renders resources/views/posts.blade.php
```

No create/update/delete routes exist — this is exactly as far as the course
took it. `UserSeeder`/`PostSeeder`/`CommentSeeder` populate demo data via
`database:seed`. One PHPUnit test (`tests/Unit/PostTest.php`) creates 5 users
with 1 post each and asserts the user count; it does not exercise the
`Post`/`Comment` relationship or any controller/route.

## Running it

```bash
docker compose up -d --build nginx mysql php
docker compose run --rm composer install
docker compose run --rm artisan key:generate
docker compose run --rm artisan migrate --seed
docker compose run --rm npm install
docker compose run --rm npm run build
```

Then visit `http://localhost/` or `http://localhost/posts`. `.env.example`
already matches `docker-compose.yml`'s `mysql` service (`DB_HOST=mysql`,
`DB_DATABASE=laraveldb`, `DB_USERNAME=laravel`, `DB_PASSWORD=secret`) — copy
it to `.env` before running `artisan`.

Run the test suite via the dedicated service:

```bash
docker compose run --rm phpunit
```

## Known, disclosed, not fixed (out of scope for a course repo)

- **`.env.example` ships a real-shaped `APP_KEY`** (not a placeholder) and
  the local-only `laravel`/`secret` MySQL credentials also hardcoded in
  `docker-compose.yml`. Both are local-Docker-network-only values with no
  external service behind them (unlike a cloud DB/API secret) — not treated
  as a live-credential exposure, but flagged so `APP_KEY` isn't reused as-is
  outside this sandbox.
- **`apache.dockerfile` and the commented-out `apache` service are dead
  weight** — kept from lesson 04, fully superseded by `nginx` from lesson
  09 onward. Removing them would be a real edit to course material this
  task's scope (documentation only, matching every prior P1 item) doesn't
  cover.
- **No CI workflow** (`.github/workflows/` doesn't exist) and no `LICENSE`.
- **Real, currently-open dependency-vulnerability branches** — GitHub/Renovate
  has open, unmerged branches specifically for
  `packagist-laravel-framework-vulnerability` and
  `packagist-phpunit-phpunit-vulnerability`, neither merged into `master`.
  `composer audit` was not run to independently corroborate (no Composer
  binary available on this machine) — this is reported from the branch
  names alone, not verified against a real audit run.
- **`npm audit` (run for real against the committed `package-lock.json`,
  `node_modules` not committed afterward):** 17 vulnerabilities (1 critical,
  12 high, 4 moderate), entirely in `vite`/`tailwindcss`/`postcss`/`axios`'s
  transitive dev dependencies (`esbuild`, `rollup`, `nanoid`, `postcss`,
  `form-data`, etc.) — none are direct, none are runtime/production deps of
  the Laravel app itself.

## GitHub's "last pushed" date is misleading

GitHub reports this repo as last pushed `2026-09-13`, but `master`'s real
last commit (`2151b28`, "13 Improving local Docker performance") is from
**March 2024**. Checked directly with `git merge-base --is-ancestor` against
every one of the 17 open remote branches (2 Dependabot + 15 Renovate,
spanning 2024-03 through 2026-09) — **none are merged into `master`**. The
`2026-09-13` date belongs to `renovate/autoprefixer-10.x-lockfile`
(pushed `2026-09-13T19:43:35Z`, matching GitHub's reported push time to
within seconds), a routine automated lockfile bump, not new course content.
Same shape of finding as this portfolio's other course/practice repos
(`ms-laravel-rabbitmq`, `qa-m-a`, `QA-KB-task`, `ms17`, `mern-bt`) — GitHub's
push-date signal tracks any branch, not necessarily the default one.
