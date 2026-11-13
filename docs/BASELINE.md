# BASELINE.md — `docker_laravel` (Phase 5)

Phase 5 container baseline. Branch `phase-5/container`, worktree
`projects/worktrees/docker_laravel`, based on `master` at `7dcf821`.

This document records what was actually built and run. It does not assume
success: where the repo is already red, the failure is reproduced and attributed.

## 1. Environment

| Tool | Version |
|---|---|
| Docker | 29.9.3 (linux/amd64, containerd 2.2.4) |
| Docker Compose | v5.7.0-desktop.1 |
| GNU Make | 4.4.1 (Git for Windows) |
| Host | Windows, PowerShell 5.1 |

## 2. Image pins and sizes

| Image | Pin | Size |
|---|---|---|
| `php` | `php:8.3-fpm-alpine@sha256:f9804e0c991b5b339d6fa4fab9edf3c9c9ae68048fb1017cb6dea6265ccef054` | 124 MB (base) |
| `composer` | `composer:2@sha256:ca11f643d7791ebdd90a34fc20caf11380d434007ae539a9ea75cd9212e13dca` | 316 MB (build-time only) |
| `nginx` | `nginx:stable-alpine@sha256:901e593c95dc85f5a729f5765516321366ef4ac401821431d408897e95287d0a` | 93.6 MB (base) |
| `mysql` | `mysql:8.4.13@sha256:a81d043930e51745522bd5c430961cf8286f0a23f0a9a2a6e0108f7ea71b0902` | 1.12 GB |
| `node` | `node:24-alpine@sha256:116b800c3754b440ee0aa3ed2f20f5bf3d99a554bfd9adeea09ea8017f6e85f5` | 244 MB (dev task runner only) |

Built Phase 5 images:

| Image | Size |
|---|---|
| `docker_laravel-p5-app:local` (runtime) | 179 MB |
| `docker_laravel-p5-web:local` (nginx) | 92.7 MB |
| `docker_laravel-p5-base:local` (dev/task runner) | 135 MB |

The runtime image contains only PHP-FPM, the PHP extensions, Composer's
autoload output and the application; dev dependencies are not in it.

## 3. Dockerfile stages

`Dockerfile` implements `base -> deps -> build -> test -> runtime`, plus
`deps-dev` and a `web` (nginx) stage.

| Stage | Purpose | Result in this phase |
|---|---|---|
| `base` | PHP 8.3-FPM Alpine, `pdo_mysql`, Composer binary, non-root `app` user (uid 1000) | **built** |
| `deps` | production `composer install --no-dev` from `composer.json` + `composer.lock` | **blocked** by pre-existing lock mismatch (§4) |
| `deps-dev` | full `composer install` for the test stage | blocked by same mismatch |
| `build` | copy app, optimized autoloader, `artisan package:discover`, storage dirs | built in the temporary validation pass |
| `test` | copy app + dev deps, PCOV, PHPUnit with text/clover coverage | **ran in a temporary validation pass**: 7 tests, 1 pre-existing failure (§5) |
| `runtime` | copy from `build`, non-root, entrypoint, `php-fpm`, port 9000 healthcheck | **built** (179 MB) |
| `web` | nginx config + `public/` from `build`, `nginx -t` healthcheck | **built** (92.7 MB) |

## 4. Pre-existing build blocker (Phase 6 scope)

`src/composer.json` and `src/composer.lock` disagree:

| Package | `composer.json` | `composer.lock` |
|---|---|---|
| `laravel/framework` | `^12.0` | `v10.43.0` |
| `phpunit/phpunit` | `^12.0` | `10.5.10` |

Composer 2.11.2 refuses to install the lock:

```text
- Required package "laravel/framework" is in the lock file as "v10.43.0"
  but that does not satisfy your constraint "^12.0".
- Required (in require-dev) package "phpunit/phpunit" is in the lock file as
  "10.5.10" but that does not satisfy your constraint "^12.0".
This usually happens when composer files are incorrectly merged or the
composer.json file is manually edited.
```

Exit code: `4`. This is not introduced by Phase 5: commits `9908c4d`
(`Update dependency laravel/framework to v12`) and `282e419`
(`Update dependency phpunit/phpunit to v12`) changed `composer.json` without
updating `composer.lock`. The application code is still Laravel 10-style
(`bootstrap/app.php`, `app/Http/Kernel.php`), so the lock is the correct
baseline for the current code.

A second, related blocker: the old `php.dockerfile` used `php:8.5-fpm-alpine`,
but the lock's `nette/schema v1.3.0` requires PHP `8.1 - 8.3` and
`nette/utils v4.0.4` requires `<8.4`. The new `base` stage therefore uses
`php:8.3-fpm-alpine`, matching the locked dependency graph and the app code.

Consequence for the committed repo:

```text
make verify  -> exit 2, fails in the `deps` stage at `composer install`
make up      -> exit 2, never starts because `up` depends on `verify`
```

Phase 6 owns the dependency repair (`composer update` to a coherent
Laravel 12/13 set, then migrate the Laravel 10-style bootstrap if needed).
No dependency files were changed in Phase 5.

## 5. Test results

The committed `test` stage cannot run until the lock is repaired. To avoid
assuming a result, the same test stage was run in a disposable copy with only
the two constraint lines temporarily aligned to the lock (`^10.10`, `^10.5`).
The repo itself was restored immediately afterwards (`git status` is clean for
`src/composer.json`).

Command:

```text
vendor/bin/phpunit --testdox --coverage-text --coverage-clover=coverage.xml
```

Environment: PHP 8.3.36, Composer 2.11.2, Laravel 10.43.0, SQLite `:memory:`,
PCOV.

Result: **7 tests, 15 assertions, 1 failure** (the failure is pre-existing).

| Test | Result |
|---|---|
| `Tests\Unit\ExampleTest::test_that_true_is_true` | PASS |
| `Tests\Unit\PostTest::test_show_posts` | PASS |
| `Tests\Feature\ExampleTest::test_the_application_returns_a_successful_response` | **FAIL** |
| `Tests\Feature\PostRoutesCharacterizationTest::test_posts_index_returns_all_posts` | PASS |
| `Tests\Feature\PostRoutesCharacterizationTest::test_post_show_returns_the_post` | PASS |
| `Tests\Feature\PostRoutesCharacterizationTest::test_post_comments_index_returns_comments` | PASS |
| `Tests\Feature\PostRoutesCharacterizationTest::test_comment_show_returns_the_comment` | PASS |

Failure detail (`Feature\ExampleTest`):

```text
Expected response status code [200] but received 500.
PDOException: SQLSTATE[HY000]: General error: 1 no such table: posts
(Connection: sqlite, SQL: select * from "posts")
at tests/Feature/ExampleTest.php:17
```

The test does not use `RefreshDatabase`, and `phpunit.xml` does not select
SQLite; it was written for a live, already-migrated MySQL database. This is the
pre-existing P1 test defect TD-05/TD-15 in `docs/TECHNICAL_DEBT.md`.

Coverage with the characterization tests (PCOV, `app/` source):

| Metric | Result |
|---|---|
| Classes | 46.67% (7/15) |
| Methods | 63.64% (14/22) |
| Lines | 62.50% (25/40) |

Before the characterization tests were added, the same run was
`3 tests, 2 passed, 1 failed` and `Lines 47.50% (19/40)`.

### Characterization tests added

`src/tests/Feature/PostRoutesCharacterizationTest.php` adds four minimal,
pre-Phase-11 tests for the previously untested read-only routes:

- `GET /posts` returns all posts as a JSON array.
- `GET /posts/{post}` returns the post.
- `GET /posts/{post}/comments` returns the post's comments.
- `GET /posts/{post}/comments/{comment}` returns the comment.

They characterize current behavior (unpaginated `Post::all()` / direct model
serialization), not a new contract. They pass against the locked Laravel 10
dependency set.

## 6. Runtime / API / CLI snapshots

A real stack was started with the temporary lock-consistent constraints
(`docker compose --env-file .env.example up -d --wait`), MySQL migrated and
seeded. This is runtime evidence; it is not `make up`, which remains blocked
by `make verify`.

Health at start:

```text
mysql   running  healthy  0.0.0.0:20221->3306/tcp
nginx   running  healthy  0.0.0.0:20220->80/tcp
php     running  healthy  9000/tcp
```

HTTP responses:

| Request | Status | Body shape |
|---|---|---|
| `GET /posts` | 200 | JSON array of posts (`id,user_id,title,content,created_at,updated_at`); 100 rows after seed |
| `GET /posts/1` | 200 | single post object |
| `GET /posts/1/comments` | 200 | JSON array of comments (`id,user_id,post_id,content,...`) |
| `GET /posts/1/comments/1` | 200 | comment object; note it returns comment 1 whose `post_id` is 3 — the route does not scope the comment to the post |
| `GET /` | **500** | `Mix manifest not found at: /var/www/html/public/mix-manifest.json` |
| `GET /api/user` | **500** | `Route [login] not defined.` |

The `/` failure is pre-existing: `resources/views/posts.blade.php` uses the
Laravel Mix helper `mix()`, but the repo has no `webpack.mix.js` and no
`public/mix-manifest.json`; the frontend is configured for Vite. The
`/api/user` failure is the known missing `sanctum`/`api` guard (TD-03).
Neither is fixed in Phase 5.

CLI snapshots:

```text
$ php artisan --version
Laravel Framework 10.43.0

$ php artisan about --only=environment
Application Name ... Laravel Docker App
Laravel Version .... 10.43.0
PHP Version ........ 8.3.36
Composer Version ... 2.11.2
Environment ........ local
Debug Mode ......... ENABLED
URL ................ localhost
Maintenance Mode ... OFF

$ php artisan route:list
GET|HEAD   / ...............................................................
POST       _ignition/execute-solution ignition.executeSolution › ...
GET|HEAD   _ignition/health-check ignition.healthCheck › ...
POST       _ignition/update-config ignition.updateConfig › ...
GET|HEAD   api/user ........................................................
GET|HEAD   posts ...................................... PostController@index
GET|HEAD   posts/{post} ................................ PostController@show
GET|HEAD   posts/{post}/comments ................... CommentController@index
GET|HEAD   posts/{post}/comments/{comment} .......... CommentController@show
GET|HEAD   sanctum/csrf-cookie sanctum.csrf-cookie › ...
Showing [10] routes
```

## 7. Secrets and supply chain

- Root `.env.example` and `src/.env.example` contain placeholders only
  (`APP_KEY=` empty, `DB_PASSWORD=change_me`,
  `MYSQL_ROOT_PASSWORD=change_me_root`). The previous real-shaped `APP_KEY`
  in `src/.env.example` was removed; it remains in git history and should be
  treated as disclosed/rotated in Phase 9.
- Runtime credentials come from `.env` (optional `env_file`) or the process
  environment; nothing is baked into the runtime image.
- `docker/php/entrypoint.sh` generates an `APP_KEY` at startup only when none
  is supplied (`php artisan key:generate --show`), and waits for `DB_HOST`/
  `DB_PORT` before starting PHP-FPM.
- The test stage's `APP_KEY` is passed as a per-command environment variable
  (a fixed dummy value), not as a Docker `ENV` instruction, to avoid baking a
  key into an image layer.
- All base images are pinned by tag and digest (table in §2). `composer:latest`
  and `node:current-alpine` from the old compose file were replaced.

Docker Scout (`docker scout quickview`):

| Image | Vulnerabilities (C/H/M/L) | Health | Policies |
|---|---|---|---|
| `docker_laravel-p5-app:local` | 2C / 19H / 36M / 9L | C (56%) | 4/7 met |
| `docker_laravel-p5-web:local` | 1C / 5H / 6M / 5L | E (28%) | 2/7 met |

Scout flags for the app image: copyleft packages, fixable critical/high
vulnerabilities (2C/17H), missing supply-chain attestations. For nginx: runs
as root, copyleft packages, fixable critical/high vulnerabilities,
high-profile vulnerability. The runtime app container is non-root; the nginx
master still runs as root (worker as `nginx`). Phase 6 should refresh base
images; Phase 9 should evaluate an unprivileged nginx image and attestations.

## 8. Compose and Makefile contract

- `docker-compose.yml` has no obsolete `version:` key; uses
  `COMPOSE_PROJECT_NAME=docker_laravel-p5`; ports are 20220 (web) and 20221
  (MySQL) from the reserved block 20220-20229; the network is named
  `docker_laravel-p5-laravel`; the MySQL data volume is `mysql-data` (named,
  not a host bind).
- `php` (runtime), `nginx` (web) and `mysql` have healthchecks;
  `nginx depends_on php: service_healthy`, `php depends_on mysql:
  service_healthy`. `docker compose up -d --wait` was observed to reach all
  three healthy states.
- `composer`, `artisan`, `phpunit`, `npm`, `npx` are dev task runners under
  the `tools` profile, so `make up` does not start them. They use pinned
  images or the `base` target and bind-mount `./src` for the course workflow.
- `make verify` = `build` + `test`; `make up` depends on `verify`. Both are
  red until Phase 6 repairs the lock. `make down` works.
- `make security` runs `composer audit` (in the `composer` service) and
  `docker scout cves`.

## 9. Residual risks / handoff

| Risk | Status | Owner |
|---|---|---|
| `composer.json`/lock mismatch blocks build | open | Phase 6 |
| Laravel 10 code vs `^12.0` constraint | open | Phase 6 |
| `GET /` 500 (Mix manifest missing) | open | Phase 8/9/11 |
| `Feature\ExampleTest` needs `RefreshDatabase`/SQLite | open | Phase 11 |
| `/api/user` missing sanctum guard | open | Phase 9 |
| `Post::all()` unpaginated; comment route not scoped | characterized | Phase 8 |
| nginx runs as root; base image CVEs; no attestations | open | Phase 6/9 |
| `apache.dockerfile` dead | untouched | Phase 7 |

No dependency, application, or documentation behavior was changed in Phase 5
beyond the Docker/Make files, the two `.env.example` placeholder fixes, and
the four characterization tests.