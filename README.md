# Workload Data Collection

As part of your cloud engagement with David Kent Consulting, we need a
snapshot of how your current systems are actually being used -- CPU,
memory, disk I/O, and Oracle database activity. These scripts collect that
data for us. They are read-only: they don't change any configuration and
are safe to run against production.

Three steps: download, run, upload.

## 1. Download

```
mkdir workload_collection_scripts && cd workload_collection_scripts
curl -L https://github.com/David-Kent-Consulting/workload_collection_scripts/archive/refs/heads/master.tar.gz | tar xz --strip-components=1
```

If this host doesn't have outbound internet access, download the tools on
another machine and copy the folder over (scp, USB, etc.), or ask your
David Kent Consulting contact to send it to you directly.

## 2. Run

**On every host you're collecting from**, run `collect_os.sh`. It captures
CPU, memory, and disk I/O for 72 hours, then packages the results into a
single file in `/tmp`. Start it on a Monday, Tuesday, or Wednesday morning
so the 72-hour window covers a normal business week, and run it in the
background so it keeps going after you log out:

```
nohup ./collect_os.sh > /tmp/collect_os.log 2>&1 &
```

**On your Oracle database host**, run `collect_db.sh`. It finds every
database currently running and asks which one is your busiest -- that one
gets a full AWR history report; every other running database gets a
quick one-hour snapshot automatically. No further input needed after you
answer that one question. This requires Oracle Enterprise Edition with the
Diagnostic Pack license.

```
./collect_db.sh
```

## 3. Upload

Both scripts leave a `.tar.gz` file in `/tmp` when they finish (one per
host, one per database). Upload each file to:

**https://upload.davidkentconsulting.com/**

When prompted, note which host or database each file came from -- that's
all we need from you. We'll take it from there.

---

Questions at any point, reach out to your David Kent Consulting contact.
