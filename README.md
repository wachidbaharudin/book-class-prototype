# Class Booking App

A configurable booking platform for learning centers: publish classes, take online payments, and track attendance, cancellations, refunds, and earned revenue — deployable per center with configuration only, no code changes.

**Status:** specification phase — architecture and payments specs are drafted; application code is not yet in the tree. See [Milestones](#milestones).

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

Current contents:

```
PRD.md                     product requirements
README.md                  this file
docs/
  SCHEMA.md                data model + invariants
  schema.sql               baseline SQL schema
  specs/                   ENG-00…09 engineering specs + index
  research/                primary-source research notes
prototypes/                static HTML prototypes
```

Target layout once implementation starts (per [ENG-00 §4](docs/specs/ENG-00-architecture.md)):

```
apps/
  web/                     Next.js — (customer) / (admin) / (teacher) route groups
  api/                     NestJS — src/modules/<domain>, src/common, src/db, src/jobs
packages/
  shared/                  zod DTOs, error codes, role enum, business-rule constants
docker-compose.yml
pnpm-workspace.yaml
```

`packages/shared` stays free of Nest/Next imports — plain TypeScript so both apps and CI scripts can consume it.

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

Implementation scaffolding does not exist yet. Once `apps/` lands, the intended local workflow is:

```bash
pnpm install
cp .env.example .env      # fill in placeholders
docker compose up -d db   # PostgreSQL 16
pnpm --filter api drizzle-kit migrate
pnpm dev                  # web + api
```

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
