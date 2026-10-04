# Class Booking App

A configurable booking platform for learning centers: publish classes, take online payments, and track attendance, cancellations, refunds, and earned revenue — deployable per center with configuration only, no code changes.

**Status:** foundation scaffolded — pnpm monorepo, dev/prod Compose topology, framework-free `packages/shared`, and the Drizzle schema + baseline migration are in the tree. Feature slices (ENG-01…09) build on top. See [Milestones](#milestones).

---

## What this is

One learning center (tutoring, courses, workshops) runs its bookable catalog here:

- **Admin** — branches, classes, sessions, price rules, cancellation policies, teachers, bookings, revenue reports.
- **Customer** — student profiles, browse, book per session or per series, pay, cancel.
- **Teacher** — schedule, roster, attendance, session notes.

Every business rule that would normally be hardcoded — pricing overrides, cancellation cutoffs, refund handling — is admin-configurable. Payments run through [Midtrans](https://midtrans.com) Core API (QRIS acquired by GoPay), sandbox by default and live by config change only.

The full product definition lives in [PRD.md](PRD.md).

---

## Documentation map

Product knowledge and engineering specs are versioned alongside the code so a change in behavior and a change in spec land in the same review.

| Document | What it covers |
|---|---|
| [PRD.md](PRD.md) | Vision, personas, domain model, functional requirements (FR-1…9), business rules, scope, milestones, open decisions |
| [docs/specs/README.md](docs/specs/README.md) | Engineering spec index, dependency order, and build sequence |
| [docs/specs/ENG-00-architecture.md](docs/specs/ENG-00-architecture.md) | Umbrella: tech stack, module map, repository layout, deployment topology, cross-cutting decisions |
| [docs/specs/ENG-01-payments.md](docs/specs/ENG-01-payments.md) | Midtrans Core API integration, `PaymentProvider` port, webhook state machine, refunds |
| [docs/midtrans-primer.md](docs/midtrans-primer.md) | Teaching companion to ENG-01: the Midtrans mental model, concepts mapped to spec sections |
| [docs/SCHEMA.md](docs/SCHEMA.md) | Data model, invariants, and critical queries |
| [docs/schema.sql](docs/schema.sql) | Baseline SQL schema (mirrored 1:1 by the Drizzle schema) |
| [docs/research/midtrans-payment-refund-mechanisms.md](docs/research/midtrans-payment-refund-mechanisms.md) | Primary-source research on QRIS/GoPay refund windows and behavior |
| [prototypes/fr1.html](prototypes/fr1.html) | Static prototype for center/account setup (FR-1) |

**Read order for a new contributor or agent:** PRD → ENG-00 → the ENG spec for the slice you're touching → SCHEMA → `docs/schema.sql`.

---

## Repository layout

```
apps/
  web/                     Next.js App Router — (customer) / (admin) / (teacher) groups
  api/
    src/db/                Drizzle schema (mirrors docs/schema.sql 1:1), client, migrations
    src/modules/           one folder per domain module (ENG-01…09)
packages/
  shared/                  framework-free zod DTOs, error codes, role enum, BR constants
scripts/                   Compose + backup/restore helpers
Caddyfile                  production reverse proxy
Dockerfile.dev             Compose development image
docker-compose.yml         production topology (caddy/web/api/db)
docker-compose.dev.yml     local dev topology (hot-reload + exposed db)
docs/ops/deployment.md     deploy, backup/restore drill, scaling story
```

`packages/shared` stays free of Nest/Next imports — plain TypeScript so both apps and CI scripts can consume it, enforced by `packages/shared/scripts/check-framework-free.mjs`.

---

## Architecture at a glance

One deployable **modular monolith** for one learning center.

| Layer | Choice |
|---|---|
| Language | TypeScript end-to-end |
| Monorepo | pnpm workspaces (`apps/web`, `apps/api`, `packages/shared`) |
| Frontend | Next.js (App Router), Tailwind CSS + shadcn/ui |
| Backend | NestJS (Express), REST + OpenAPI |
| Database | PostgreSQL 16, Drizzle ORM |
| Validation | zod schemas in `packages/shared` |
| Auth | HTTP-only DB-backed session cookie, argon2id |
| Scheduling | `@nestjs/schedule` cron in the API process |
| Money | Dinero.js v2, `BIGINT` IDR at the DB edges |
| Infra | Docker Compose: Caddy (TLS) + web + api + db on a single VPS |

Database-level invariants (seat locking, partial unique indexes, append-only money tables) are described in [docs/SCHEMA.md](docs/SCHEMA.md); the stack rationale and rejected alternatives are in [ENG-00 §3](docs/specs/ENG-00-architecture.md).

---

## Getting started

The scaffold is in place; feature slices land on top.

```bash
pnpm install
cp .env.example .env                       # placeholders are fine for local dev
pnpm dev                                   # db + api + web via Docker Compose (hot-reload)
pnpm --filter @bookclass/api db:migrate    # apply the baseline schema once the stack is up
```

- web → http://localhost:3001 · api → http://localhost:4000/api/v1
- `pnpm dev:down` stops the stack. Local ops drill: `COMPOSE_FILE=docker-compose.dev.yml pnpm db:backup`, then `COMPOSE_FILE=docker-compose.dev.yml pnpm db:restore <dump>`.
- Production deploy, backup/restore runbook, and the scaling story: [docs/ops/deployment.md](docs/ops/deployment.md).

### Configuration & secrets

Committed files use **placeholders only**. Expected environment variables (names only):

```
DATABASE_URL=
APP_ENCRYPTION_KEY=
MIDTRANS_CLIENT_KEY=
MIDTRANS_SERVER_KEY=
MIDTRANS_IS_PRODUCTION=false
MAILER_DSN=
```

Real values live in a git-ignored `.env` for local work, or in a private per-client deployment repo that holds config, branding, and keys. The product repo stays generic. **Never commit real credentials.**

---

## Milestones

Derived from PRD §9. Payment risk is retired before anything depends on it.

| M | Deliverable |
|---|---|
| M0 | Midtrans sandbox Core API spike: QRIS charge, webhook confirm, full/partial refunds, refund windows, QR expiry |
| M1 | Auth + roles + center config + student profiles |
| M2 | Classes, sessions, price rules, policies, teacher assignment |
| M3 | Booking + sandbox payment + settlement ledger |
| M4 | Attendance, notes, settlement tracking, revenue report |
| M5 | Cancellation/refund engine + notifications + polish |

Spec dependency order is documented in [docs/specs/README.md](docs/specs/README.md): risk path ENG-01 → ENG-02 → ENG-05; ENG-07/03/04 build in parallel.

---

## Conventions

- **Specs are the source of truth for behavior.** If code and spec disagree, fix the spec in the same change or record the decision explicitly.
- **A table is written by exactly one module.** Cross-module reads via SQL joins are fine; writes go through the owning module's service.
- **Money tables are append-only.** State transitions forward; never update destructively.
- **One spec per slice.** New cross-cutting decisions go in ENG-00; sub-specs reference, never redefine.
- **This repository is public.** Committed content must contain no credentials, personal contact details, or real client identities. Use `example.com` addresses and fictional names in examples.
