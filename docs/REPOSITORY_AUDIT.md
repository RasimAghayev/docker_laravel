# REPOSITORY_AUDIT.md

Full Phase 3 audit of `docker_laravel` (PHP/Laravel course repo). Canonical clone HEAD `0a4514f` on `master`; audit performed in worktree `projects/worktrees/docker_laravel/`. No production code changed — documentation/analysis only.

## 1. File inventory

| Path | Role |
|---|---|
| `docker-compose.yml` | Compose v3.8, 9 services (nginx, php, mysql, composer, artisan, phpunit, npm, npx, apache commented out) |
| `nginx.dockerfile` | `FROM nginx:stable-alpine`, adds `nginx/default.conf` |
| `nginx/default.conf` | nginx site: root `/var/www/html/public`, php:9000 |
| `php.dockerfile` | `FROM php:8.3-fpm-alpine`, installs pdo/pdo_mysql |
| `apache.dockerfile` / `apache/httpd-vhosts.conf` | Dead weight from lesson 04; service commented out |
| `Command.txt` | Course command cheat-sheet (verbatim) |
| `README.md` | Repo docs, stack, run instructions, known issues |
| `src/composer.json` / `src/composer.lock` | PHP deps: Laravel 10, Sanctum, Guzzle, phpunit 10.x |
| `src/package.json` / `src/package-lock.json` | Frontend devDeps: Vite, Tailwind, Axios |
| `src/.env.example` | Real `APP_KEY` + `DB_PASSWORD=secret` (P0) |
| `src/config/*.php` | 12 Laravel config files |
| `src/routes/{web,api,channels,console}.php` | 5 routes + 1 Sanctum-protected `/api/user` |
| `src/app/Http/Controllers/{Post,Comment}Controller.php` | Read-only controllers, no validation |
| `src/app/Models/{User,Post,Comment}.php` | Eloquent models, `$guarded=[]` on Post/Comment |
| `src/database/migrations/*` | 6 migrations; FKs commented out |
| `src/database/factories/*` | 3 factories; hardcoded ID ranges |
| `src/database/seeders/*` | 4 seeders; DatabaseSeeder wires only UserSeeder |
| `src/tests/` | 3 test files; PostTest uses RefreshDatabase |
| `src/phpunit.xml` | PHPUnit config; sqlite lines commented out |
| `.vscode/settings.json` | Committed IDE artifact |
| `.gitignore` (root) | Only `mysql/*` |

No `.github/workflows/`, no `Makefile`, no `.dockerignore`, no LICENSE, no `.env` committed.

## 2. Dependency analysis

### Composer (PHP)

`src/composer.lock` satisfies every `src/composer.json` requirement:

| Package | require | locked |
|---|---|---|
| laravel/framework | ^10.10 | v10.43.0 |
| laravel/sanctum | ^3.3 | v3.3.3 |
| laravel/tinker | ^2.8 | v2.9.0 |
| guzzlehttp/guzzle | ^7.2 | 7.8.1 |
| phpunit/phpunit | ^10.1 (dev) | 10.5.10 |
| php | ^8.1 | — (runtime) |

Full lock inventory (62 packages): brick/math, carbonphp/carbon-doctrine-types, dflydev/dot-access-data, doctrine/inflector, doctrine/lexer, dragonmantank/cron-expression, egulias/email-validator, fakerphp/faker, filp/whoops, fruitcake/php-cors, graham-campbell/result-type, guzzlehttp/{guzzle,promises,psr7,uri-template}, hamcrest/hamcrest-php, laravel/{framework,pint,prompts,sail,sanctum,serializable-closure,tinker}, league/{commonmark,config,flysystem,flysystem-local,mime-type-detection}, mockery/mockery, monolog/monolog, myclabs/deep-copy, nesbot/carbon, nette/{schema,utils}, nikic/php-parser, nunomaduro/{collision,termwind}, phar-io/*, phpoption/phpoption, phpunit/{php-code-coverage,php-file-iterator,php-invoker,php-text-template,php-timer,phpunit}, psr/*, psy/psysh, ralouphie/getallheaders, ramsey/{collection,uuid}, sebastian/*, spatie/{backtrace,flare-client-php,ignition,laravel-ignition}, symfony/*, theseer/tokenizer, tijsverkoyen/css-to-inline-styles, vlucas/phpdotenv, voku/portable-ascii, webmozart/assert.

Staleness vs latest stable: **unverified** — `php`/`composer` are not installed on this host, so `composer outdated --direct` / `composer update --dry-run` / `composer audit` could not be run locally. Lockfile timestamps cluster at Jan–Feb 2024; defer registry check to Phase 6.

Dead/questionable dependencies:
- `laravel/sanctum` — installed and referenced (`User::HasApiTokens`, `api.php` `auth:sanctum`), but `config/auth.php` has no `sanctum`/`api` guard → misconfigured/broken rather than dead (see C).
- `laravel/tinker` — dev REPL, legitimately required.

### npm (Node)

`npm audit` run live against committed `src/package-lock.json` with `node_modules` present:

```
$ npm audit --registry https://registry.npmjs.org/
EXIT: 1
19 vulnerabilities (5 moderate, 13 high, 1 critical)
```

Vulnerable packages (all transitive dev tooling, none runtime/production deps of the Laravel app): axios, brace-expansion, braces, browserslist, cross-spawn, esbuild (via vite), follow-redirects, form-data (critical), glob, micromatch, minimatch, nanoid, picomatch, postcss, postcss-selector-parser, rollup, source-map-js, yaml. All report `fix available via npm audit fix`.

README cites 17 vulnerabilities — stale; live count is 19.

## 3. Config review

| File | Key settings | Finding |
|---|---|---|
| `config/auth.php` | guard `web` only; provider `users` → `App\Models\User` | Missing `api`/`sanctum` guard (P1-C) |
| `config/hashing.php` | driver `bcrypt`, rounds env default 12 | OK; no bcrypt/SHA1 dual-strategy confusion |
| `config/cors.php` | origins/methods/headers `['*']` | Wide-open CORS (P2-D) |
| `config/sanctum.php` | guard `['web']`, stateful localhost domains | Guard referenced but not defined in auth.php |
| `config/session.php` | `secure: null`, `same_site: lax`, `http_only: true` | Secure flag not forced (P2-K) |
| `config/database.php` | default `mysql`, strict mode on | OK |

## 4. Code quality findings

- Controllers return models directly (`return $post;`, `return Post::all()`) — no validation, no pagination (`Post::all()` unbounded, P2-M).
- `Post`/`Comment` models have `$guarded = []` — full mass-assignment surface.
- Migrations use plain `integer()` columns with commented-out `foreignId()->constrained()` — no referential integrity (P2-L).
- `DatabaseSeeder` calls only `UserSeeder`; `PostSeeder`/`CommentSeeder` exist but unused.
- `UserSeeder` uses factory states `->hasPosts(20)->hasComments(20)`; `PostSeeder->forUser(3)` hardcodes user ID 3; `CommentFactory` uses `numberBetween(1, 20)` / `numberBetween(1, 3)` — all break when `RefreshDatabase` resets IDs (P1-F).
- `PostTest` only asserts `users` count; never exercises Post/Comment relationship or any route (test coverage gap).
- `app/Console/Kernel.php` schedule empty; `routes/console.php` only `inspire`.
- No `app/Http/Resources/` directory (no API resources).

## 5. Security scan

- Working-tree secret grep: no `.env`, no keys, no tokens committed.
- Git history scan: 15 commits on `master` only (`first commit`, lessons 01–13, two docs commits); commit messages contain no secrets. Local clone has only `origin/master` (README's 17 open remote branches not fetched).
- `src/.env.example` contains a real `APP_KEY` value (redacted here) and `DB_PASSWORD=secret` (P0-A/B).
- `docker-compose.yml` hardcodes `MYSQL_ROOT_PASSWORD=secret`, `MYSQL_PASSWORD=secret`, exposes `4306:3306` (P0-B).
- CORS `['*']` on all methods/headers (P2-D).
- Session `secure` cookie unset (P2-K).
- No pre-commit secret scan, no CI secret scan, no GitHub secret scanning configured (no CI exists).
- `.vscode/settings.json` committed (IDE artifact, P1-I).

## 6. CI/CD status

- No `.github/workflows/` — no CI pipeline exists.
- No Dependabot config (no `.github/dependabot.yml`).
- README references open Dependabot/Renovate vulnerability branches (`packagist-laravel-framework-vulnerability`, `packagist-phpunit-phpunit-vulnerability`) but they are not present in the local clone (only `origin/master`); `composer audit` was not run to corroborate.
- Phase 10 (CI/CD) applies: add GitHub Actions workflow running composer install + PHPUnit inside a Docker test stage.

## 7. Git hygiene

- 15 commits, linear history on `master`; all commits are course lessons or docs (01 Introduction to Docker … 13 Improving local Docker performance + README docs).
- No branches locally (`master` only); remote shows `origin/master` only.
- `.vscode/` committed at root (violates CLAUDE.md decision 13).
- Root `.gitignore` covers only `mysql/*`; ignores for `.env`, `vendor`, `node_modules`, IDE dirs live only under `src/.gitignore`.
- No `.gitattributes`.

## 8. Docker inventory

- Images not digest-pinned: `composer:latest`, `node:current-alpine`, `nginx:stable-alpine`; `php:8.3-fpm-alpine` in `php.dockerfile` (G-P).
- `php` and `artisan` services run as `user: "0:0"` (root) (P1-H).
- No `.dockerignore`, no `HEALTHCHECK`, no multi-stage builds, no `Makefile`.
- Volumes: `./src:/var/www/html:delegated`, `./mysql:/var/lib/mysql` (host data dir).
