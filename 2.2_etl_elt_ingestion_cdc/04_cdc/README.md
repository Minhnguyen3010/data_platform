# CDC labs

This module compares two CDC approaches:

- `query_based/` polls a queryable change log with a timestamp-plus-ID
  checkpoint. It demonstrates upsert, hard-delete events, soft-delete flags,
  deduplication and repeatable polling.
- `postgres_logical_replication/` runs two PostgreSQL 16 instances. The source
  publishes customer changes and the target subscribes to them asynchronously.
  This is log-based CDC, not a polling query.

For the log-based lab, copy `.env.example` to `.env`. The example password is
for local practice only. If you change it, update the password in
`postgres_logical_replication/seed/03_subscribe.sql` to match.

Run the source seed before creating the subscription. The target starts empty;
`copy_data = true` copies the initial source rows. Apply
`postgres_logical_replication/seed/04_changes.sql` on the source and run
`postgres_logical_replication/seed/05_assertions.sql` on the target. The
assertion waits briefly for asynchronous apply, then verifies:

- Customer 1's update is present.
- Customer 2's hard delete is absent.
- Customer 3's soft-delete flag is present.

The source table has a primary key, so PostgreSQL can replicate update and
delete events. In production, use a dedicated least-privilege replication role,
secure credentials, monitor replication slots, and plan for initial snapshots,
retention, and recovery. The superuser account here is only to keep the local
lab setup compact.
