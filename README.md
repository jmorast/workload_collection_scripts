# workload_collection_scripts

Data collection for a David Kent Consulting cloud engagement. This
determines the existing workload of a client's Linux hosts and Oracle
databases (12c or later) ahead of a cloud migration or sizing decision.

## What to do

**1. Download this repo onto the client's host(s).**

```
git clone https://github.com/David-Kent-Consulting/workload_collection_scripts.git
cd workload_collection_scripts
```

If you can't reach GitHub from the client site, download a zip of the repo
elsewhere and copy it over (scp, USB, etc.).

**2. Run the collection scripts.**

- `./collect_os.sh` -- run this on every host you need workload data for.
  It runs unattended for 72 hours capturing CPU, memory, and disk I/O, then
  produces one `.tar.gz` in `/tmp`. Start it on a Monday, Tuesday, or
  Wednesday morning so the window covers a normal business cycle, and
  background it so it survives you logging out:

  ```
  nohup ./collect_os.sh > /tmp/collect_os.log 2>&1 &
  ```

- `./collect_db.sh` -- run this once on the DB host. It discovers every
  currently running Oracle instance and asks which one needs full AWR
  history (every retained snapshot, one report per hour) -- pick the
  "heavy hitter" the engagement actually cares about. Every *other*
  running database automatically gets a lighter single report covering
  just its most recent hour, as a spot-check. It requires Oracle
  Enterprise Edition with the Diagnostic Pack license -- confirm the
  client is licensed for AWR before running it. Each database produces
  its own `.tar.gz` in `/tmp`, and it prints a summary of all of them when
  it finishes.

  ```
  ./collect_db.sh
  ```

  You can also name the database that needs full AWR history up front to
  skip the prompt: `./collect_db.sh <ORACLE_SID>`.

**3. Upload the results.**

Every `.tar.gz` left in `/tmp` by the scripts above needs to be uploaded
manually to **https://upload.davidkentconsulting.com/**. For each file,
describe what it is -- client name, hostname or database name, and the
date range it covers.

## extras/

Optional tools not part of the standard collection above -- ad hoc SQL
diagnostics and load-testing scripts. See `extras/README.md`. Load-testing
scripts should only be run against production during an approved outage
window.

## License

GNU General Public License v2 (or later). See
https://www.gnu.org/licenses/gpl-2.0.html
