# IMPROVEMENT_ROADMAP.md

Improvement roadmap for `docker_laravel` — Phases 4–15 per `PROMPT.md`, scoped to this course repo (KISS/YAGNI apply; Docker learning material, not a production service). Phase 3 (this audit) is complete and Gate 10 is pre-approved per PROMPT.md §3; Phase 4+ may proceed.

## Phase 4 — Git hygiene

Tasks:
1. Remove committed `.vscode/` from history/working tree (add to `.gitignore` first; history rewrite only if secrets found — none found, so no Gate 1).
2. Extend root `.gitignore` with `.env`, `vendor`, `node_modules`, IDE dirs.
3. Verify history is secret-free (full-history scan already done: 15 commits, clean).

Acceptance: only `main`/`test` branches; `.vscode/` ignored; root `.gitignore` covers secrets/dependencies/IDE artifacts; no open non-bot PRs.

## Phase 5 — Container baseline

Tasks:
1. Replace floating tags with digest-pinned base images (`php:8.3-fpm-alpine@sha256:…`, `nginx:stable-alpine@sha256:…`, `mysql:8.3.0@sha256:…`).
2. Non-root runtime user for php/artisan containers (replace `user: "0:0"`).
3. Add `.dockerignore` (`.git`, `.env*`, keys, `vendor`, `node_modules`, `public/build`, tests artifacts, docs).
4. Add `HEALTHCHECK` to nginx/php containers; exec-form `ENTRYPOINT`; `SIGTERM` handling.
5. Add `Makefile`: `make build`, `make test`, `make verify` (= build + test), `make up` (depends on verify), `make run`, `make down`, `make lint`, `make shell`, `make logs`, `make migrate`, `make seed`, `make security`.
6. `docker-compose.yml`: healthchecks, `depends_on: condition: service_healthy`, `COMPOSE_PROJECT_NAME=docker_laravel-p5`, ports from `ports.md`.
7. Build image and run test suite inside the `test` stage; record baseline in `docs/BASELINE.md`.

Acceptance: `make verify` exit 0 (or pre-existing red baseline documented), `make up` starts only after verify, image scanned with 0 Critical findings or documented baseline.

## Phase 6 — Upgrade to latest

Tasks (order: runtime → framework → libraries → dev tools):
1. Laravel 10 → latest 10.x; PHP 8.3 → latest stable; composer/npm deps → latest stable (registry read at run time).
2. One dependency/group per step: bump → `make verify` in Docker → commit (`build(deps): …`) → next.
3. Migration notes for breaking changes + `CHANGELOG.md`; Gate 5 only if this repo's own public contract breaks.
4. Add `.github/dependabot.yml` (weekly, Monday 06:00 UTC; Composer, npm, Docker, Actions; PR limits 10/5; prefixes `build(deps)`/`build(deps-dev)`/`ci(deps)`).

Acceptance: every dependency/runtime/base image/action at latest stable or with written blocker; `make verify` green; no regression vs Phase 5 baseline.

## Phase 7 — Dead code & restructure

Tasks:
1. Remove `apache.dockerfile`, `apache/httpd-vhosts.conf`, commented `apache` service (dead weight, disclosed in README).
2. Re-shape layout to upgraded framework conventions only where a real problem exists.

Acceptance: no known dead code; structure matches upgraded stack; `make verify` green.

## Phase 8 — Architecture

Apply only where it earns a "why here":
- KISS/YAGNI: always (win conflicts).
- SOLID/DRY: only for repeated real logic — this CRUD course app has none identified.
- No DDD/EDA/modular monolith boundaries (single-purpose course app).

Acceptance: every applied principle justified in `docs/ARCHITECTURE.md` + ADR; every skipped principle has a one-line reason; `make verify` green.

## Phase 9 — Hardening

Tasks:
1. TD-01/TD-02: secrets out of `.env.example` (placeholders only), DB credentials env-only.
2. TD-03: add missing `api`/`sanctum` guard or fix `/api/user` middleware.
3. TD-04: restrict CORS origins/methods/headers.
4. TD-11: force session `secure` cookie over HTTPS.
5. Dependency-vulnerability remediation (npm `audit fix` for dev tooling; composer audit in Phase 6).
6. Pre-commit secret scan; CI secret-scan job; recommend GitHub secret scanning + push protection.

Acceptance: security checklist documented with results; no secrets in code/history/images/CI; `make verify` green.

## Phase 10 — CI/CD

Tasks:
1. Add GitHub Actions workflow: install+cache → format/lint + secret scan (parallel, first) → tests (Docker `test` stage) → build → image/dependency scan.
2. `concurrency` with `cancel-in-progress` on PRs; `timeout-minutes` on every job; actions pinned by SHA.
3. Pipeline ≤ 10 min wall-clock (measure, record in `docs/TEST_REPORT.md`).
4. Publish only on tag from protected branch; fork PRs get no secrets.

Acceptance: real CI run green within time budget or overrun documented.

## Phase 11 — Tests

Tasks:
1. Enable sqlite `:memory:` for unit tests (or Docker test DB); fix `PostTest` DB connection.
2. Fix hardcoded seed IDs (TD-06); use factory-returned instances.
3. Add route/controller tests for all 5 GET routes + `/api/user` auth behavior.
4. `docs/TESTING_STRATEGY.md` + `docs/TEST_REPORT.md` with real results; test IDs `TC_<MODULE>_<SCENARIO>_<N>` (e.g. `TC_POSTS_INDEX_001`), each PASS/FAIL/BLOCKED/NOT RUN/SKIPPED/N/A.

Acceptance: suite green in Docker and in CI; coverage reported honestly; no weakened/skipped failing tests.

## Phases 12–17

- Phase 12 merge small repos: n/a (single-course-repo, not a merge candidate).
- Phase 13 shared library: n/a (no ≥3-place duplication identified).
- Phase 14 rename: format `<short_business_name>_BestPracticeArcht` — Gate 2 decision only.
- Phase 15 docs/manifest/diagrams: `repo-manifest.yaml`, `README.md`, `CHANGELOG.md`, Merghan diagrams from real code only.
- Phase 16 platform repo: n/a.
- Phase 17 final report: `projects/info/REPORT.md`.

## Critical path

Gate 10 approval → Phase 4 → Phase 5 (Docker baseline is the behavior contract) → Phase 6 → … → Phase 11 → Phase 17. Phases 8/12/13/16 are n/a or modest for this repo.

## Notes

- No production code changes in Phase 3; all remediation is Phase 4+.
- Baseline = behavior contract: record Phase 5 `make verify` results before any change (CLAUDE.md).
