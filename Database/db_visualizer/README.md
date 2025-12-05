# Simple DB Viewer (Optional)

This lightweight Node.js viewer is provided for local development and debugging. It is not required for the Database container to function and is **disabled by default** to avoid unnecessary Node.js processes in the database environment.

## Why disabled by default?

- The Database container’s primary responsibility is running PostgreSQL.
- Starting a Node.js service inside the same container can lead to startup failures if dependencies are not installed.
- Avoids `MODULE_NOT_FOUND` errors for `express` or other packages during database startup.

## How to enable

Option 1 — Enable via environment variable when running `Database/startup.sh`:

```bash
export DB_VISUALIZER_ENABLED=true
bash cloudunify-pro-284073-286484/Database/startup.sh
```

This will:
- Install dependencies if missing: `npm install --omit=dev`
- Start the viewer in the background at `0.0.0.0:3000` (by default)
- Log output to `Database/logs/db_visualizer.log`

Option 2 — Run manually:

```bash
cd cloudunify-pro-284073-286484/Database/db_visualizer
npm install --omit=dev
source postgres.env   # optional convenience for PostgreSQL settings
node server.js --host 0.0.0.0
```

## Scripts

`package.json` does not define a default `start` script to avoid accidental auto-starts. Use:

- `npm run start:viewer` — Start the viewer
- `npm run dev:viewer` — Start in dev mode (uses nodemon)

## Environment variables

You can supply connection info via these files (Bash `export` format):

- `postgres.env` — for PostgreSQL
- `mysql.env` — for MySQL
- `sqlite.env` — for SQLite (set `SQLITE_DB`)
- `mongodb.env` — for MongoDB

The `startup.sh` script writes a `postgres.env` file automatically after PostgreSQL setup completes.

## Troubleshooting

- `MODULE_NOT_FOUND: express` — Run `npm install --omit=dev` in this folder.
- Ensure `node` and `npm` are available in the environment if relying on the auto-start path (`DB_VISUALIZER_ENABLED=true`).
