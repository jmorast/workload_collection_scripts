# extras

Not part of the standard client data collection. These are optional tools a
DBA can reach for manually during deeper analysis, or under an approved
outage window — see the top-level `README.md` for the required collection
steps.

- `sql_scripts/` -- ad hoc diagnostic queries (tablespace usage, wait
  events, top SQL by CPU, etc.), plus the original interactive
  `awr_generator.sql` that `collect_db.sh` is based on.
- `sql_loadtest_scripts/` -- load-testing scripts. **Running these against a
  production system without authorization will be disruptive.** Only run
  them during an approved outage window, with a qualified DBA at the
  controls.
