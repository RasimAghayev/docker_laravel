# TECHNICAL_DEBT.md

Technical debt register for `docker_laravel` (Phase 3 audit). Items classified P0–P3 with remediation targets mapped to phases. Phase 3 is documentation-only: no items fixed here.

## Debt register

| ID | Priority | Location | Issue | Remediation | Target phase |
|---|---|---|---|---|---|
| TD-01 | P0 | `src/.env.example` | Real `APP_KEY` value shipped (not placeholder) | Replace with `APP_KEY=` placeholder only; rotate if ever used | 9 Hardening |
| TD-02 | P0 | `src/.env.example`, `docker-compose.yml` | Hardcoded DB credentials (`DB_PASSWORD=secret`, `MYSQL_ROOT_PASSWORD=secret`, `MYSQL_PASSWORD=secret`) | Move to env-only, placeholders in `.env.example` | 9 Hardening |
| TD-03 | P1 | `src/routes/api.php` + `src/config/auth.php` | `/api/user` uses `auth:sanctum`; only `web` guard exists | Add `api`/`sanctum` guard to `config/auth.php` or remove middleware | 9 Hardening |
| TD-04 | P1 | `src/config/cors.php` | `allowed_origins/methods/headers: ['*']` | Restrict to known origins/methods/headers | 9 Hardening |
| TD-05 | P1 | `src/phpunit.xml`, `src/tests/Unit/PostTest.php` | `RefreshDatabase` test requires live MySQL; sqlite in-memory commented out | Enable sqlite `:memory:` testing DB or provide Docker test DB | 11 Tests |
| TD-06 | P1 | `src/database/seeders/PostSeeder.php`, `src/database/factories/CommentFactory.php` | Hardcoded IDs (`forUser(3)`, ranges 1–20/1–3) break on DB reset | Use factory-returned instances / captured IDs | 11 Tests |
| TD-07 | P1 | `docker-compose.yml`, `php.dockerfile`, `nginx.dockerfile` | Floating image tags not digest-pinned | Pin base images by tag + digest | 5 Container baseline |
| TD-08 | P1 | `docker-compose.yml` | `php`/`artisan` run as root (`0:0`) | Non-root runtime user | 5 Container baseline |
| TD-09 | P1 | repo root | `.vscode/settings.json` committed; root `.gitignore` incomplete | Remove `.vscode/`, add to `.gitignore`; extend root ignores | 4 Git hygiene |
| TD-10 | P2 | `src/database/migrations/*` | Foreign key constraints commented out | Uncomment/add FK constraints | 6 Upgrade / 9 Hardening |
| TD-11 | P2 | `src/config/session.php` | Session `secure` cookie unset | Force secure over HTTPS | 9 Hardening |
| TD-12 | P2 | `src/app/Http/Controllers/PostController.php` | `Post::all()` unbounded | Add pagination | 8 Architecture |
| TD-13 | P3 | `src/app/Http/Controllers/` | Controllers return models directly (serialization surface) | Explicit response arrays / resources | 8 Architecture |
| TD-14 | P3 | repo | No healthchecks, no Makefile, no CHANGELOG, no LICENSE, no CI workflow | Add Docker healthchecks, Makefile, GitHub Actions | 5 / 10 |
| TD-15 | P3 | `src/` | No route/controller tests; single PostTest asserts user count only | Add route + controller test suite | 11 Tests |
| TD-16 | P3 | `src/` | Dead weight: `apache.dockerfile`, commented `apache` service | Remove course-dead artifacts | 7 Dead code |

## Remediation roadmap mapping

- Phase 4 (git hygiene): TD-09.
- Phase 5 (container baseline): TD-07, TD-08, TD-14 (Dockerfile/compose/Makefile/healthchecks).
- Phase 6 (upgrade): TD-10 (FK constraints with framework upgrade), dependency bumps.
- Phase 7 (dead code): TD-16.
- Phase 8 (architecture): TD-12, TD-13 (only where a real problem exists; KISS/YAGNI apply — course app is CRUD-style).
- Phase 9 (hardening): TD-01, TD-02, TD-03, TD-04, TD-11.
- Phase 10 (CI/CD): TD-14 (pipeline).
- Phase 11 (tests): TD-05, TD-06, TD-15.

## Burndown targets

- P0 items: 0 remaining before Phase 4 starts (they are documented; fixed in Phase 9).
- P1 items: all assigned to phases 4/5/9/11; none block Phase 4 (Gate 10 is plan approval only).
- P2/P3 items: phased across 6–11 per table; no target dates set (course repo, low traffic).

## Notes

- This repo is Docker learning material, not a production service; remediation effort should stay proportional (CLAUDE.md KISS/YAGNI).
- No AI attribution in any remediation commit/PR.
