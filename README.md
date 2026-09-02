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

- `./collect_db.sh` -- run this on the DB host once for each database that
  matters to the engagement (it asks for the `ORACLE_SID` each time; run it
  again for additional databases). It requires Oracle Enterprise Edition
  with the Diagnostic Pack license -- confirm the client is licensed for
  AWR before running it. It pulls all currently-retained AWR history and
  produces one `.tar.gz` in `/tmp`.

  ```
  ./collect_db.sh
  ```

  Not every database on a host needs this -- use your judgment on which
  databases are actually worth profiling. Lighter databases sharing a host
  with a heavily-used one are already reflected in that host's OS-level
  data from step 2.

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
