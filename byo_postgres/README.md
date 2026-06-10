# Bring Your Own PostgreSQL — end-to-end test

Validates the guide `40-bring-your-own-postgresql.md`:
installing Krateo against a pre-existing PostgreSQL instance, with CNPG disabled.

## What it proves

1. **No CNPG** — the `no-cnpg` profile takes effect (no `pg-cluster` service, no CNPG `Cluster`).
2. **The platform comes up** — `deviser`, `resources-ingester`, `resources-presenter`,
   `events-ingester`, `events-presenter` all become Ready against the external DB.
3. **`deviser` bootstraps the schema** in the external database exactly as documented —
   `krateo_resources`, `k8s_events.event_id` (NOT NULL), the `001_k8s_events_event_id`
   migration, the `notify_new_event` JSON payload — **using native `gen_random_uuid()`
   with no `pgcrypto` and no superuser**.

## How it works

```
kind (dedicated, ephemeral)
  └─ external-db ns:  plain PostgreSQL Deployment  (your "own" DB, not CNPG)
       └─ guide SQL:  CREATE USER "krateo-db-user" … ; CREATE DATABASE "krateo-db" OWNER …
  └─ krateo-system:   krateo-db secret (DB_USER/DB_PASS, pre-created)
       └─ krateoctl install apply --profile no-cnpg,custom-cnpg-profile --init-secrets
```

`--init-secrets` is skip-if-exists, so the pre-created `krateo-db` secret (pointing at the
external DB) is preserved; krateoctl only fills in the rest. The `custom-cnpg-profile` is a
local profile file (rendered into `.run/`) that points every DB-dependent component's
`DB_HOST`/`DB_PORT`/`DB_NAME` at the external Service.

## Prerequisites

`kind`, `kubectl`, `helm`, `jq`, `krateoctl` on `PATH`, and a running Docker daemon.
The test uses its **own** kubeconfig (`.run/kubeconfig`) and never touches your current
cluster or context.

## Running

```sh
KRATEO_VERSION=<release> ./e2e.sh
```

`KRATEO_VERSION` is **required**. ⚠️ It must be a Krateo release whose bundled `deviser`
uses native `gen_random_uuid()` (the no-`pgcrypto` migration). Against an older `deviser`,
the documented owner-only role (no `CREATE EXTENSION`) cannot create the schema and the
test will fail — correctly, because the guide's "no extensions / no superuser" promise does
not hold for that build.

Useful knobs (see [`byo_postgres.conf`](./byo_postgres.conf) for all):

| Variable | Default | Purpose |
|---|---|---|
| `KRATEO_VERSION` | _(required)_ | Krateo release to install |
| `POSTGRES_IMAGE` | `postgres:17-alpine` | external DB image (guide requires ≥ 13) |
| `BYO_CLUSTER_NAME` | `krateo-byo-e2e` | kind cluster name |
| `BYO_KEEP_CLUSTER` | `false` | keep the cluster up after the run for debugging |

## Layout

```
byo_postgres/
├── e2e.sh                 # entrypoint: runs the steps in order, tears down on exit
├── byo_postgres.conf      # all configuration (env-overridable)
├── lib.sh                 # helpers + KUBECONFIG isolation; sources ../utils/common.sh
├── manifests/             # templates (@@TOKENS@@ rendered into .run/)
│   ├── postgres.yaml
│   └── krateo-overrides.custom-cnpg-profile.yaml
└── steps/                 # each step is independently runnable for debugging
    ├── 00_kind_up.sh
    ├── 10_external_postgres.sh
    ├── 20_provision_db.sh
    ├── 30_secret_and_profile.sh
    ├── 40_install_krateo.sh
    └── 50_verify.sh
```

To debug a single phase, run the step directly (after the earlier ones), e.g.
`./steps/50_verify.sh` — it sources the same isolated kubeconfig.
