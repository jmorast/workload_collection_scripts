#!/bin/bash

# Collects Oracle AWR workload data for a David Kent Consulting cloud
# engagement. Run this once per database that needs to be profiled (it will
# ask for the ORACLE_SID each time). It pulls the entire AWR history
# currently retained by that database, generates one HTML report per
# snapshot interval, and packages everything into a single .tar.gz in /tmp.
#
# AWR report generation logic adapted from awr-generator.sql, originally
# authored by flashdba (http://flashdba.com, 2014) and modified by
# hankwojteczko@davidkentconsulting.com. See extras/sql_scripts/awr_generator.sql
# for the original, interactive version.
#
# REQUIREMENTS
# ============
# - Run as (or su to) the Oracle software owner (usually the "oracle" OS user).
# - The target database must be Oracle Enterprise Edition with the
#   Diagnostic Pack license. AWR is a licensed feature -- confirm the client
#   is licensed for it before running this.
# - oraenv must be on your PATH (standard on any Oracle install).
# - tar, gzip.
#
# HOW TO RUN
# ==========
#   ./collect_db.sh
# or non-interactively:
#   ./collect_db.sh <ORACLE_SID>
#
# Run it again for every other database on this host that needs AWR data
# collected. When it finishes, it prints the path to a single .tar.gz.
# Upload that file to https://upload.davidkentconsulting.com/ and describe
# it as AWR data for that database, with the date range it covers.

set -u

total_steps=6
step() {
	echo ""
	echo "[$1/$total_steps] $2"
}

sid="${1:-}"
if [ -z "$sid" ]; then
	ps_snapshot=$(ps -ef)
	running_sids=$(echo "$ps_snapshot" | awk -F'ora_pmon_' '/ora_pmon_/{print $2}' | sort -u)
	if [ -n "$running_sids" ]; then
		echo "Currently running Oracle instances on this host:"
		echo "$running_sids" | sed 's/^/  - /'
		echo ""
	else
		echo "No running Oracle instances detected (looked for ora_pmon_* processes)."
		echo ""
	fi
	read -rp "Enter the ORACLE_SID to collect AWR data for: " sid
fi
if [ -z "$sid" ]; then
	echo "No ORACLE_SID given, exiting."
	exit 1
fi

step 1 "Validating ORACLE_SID '$sid'..."
oratab="/etc/oratab"
if [ -f "$oratab" ] && ! grep -Eq "^${sid}:" "$oratab"; then
	echo "'$sid' was not found in $oratab. SIDs registered on this host:"
	grep -Ev '^#|^$' "$oratab" | cut -d: -f1 | sed 's/^/  - /'
	read -rp "Continue anyway with SID '$sid'? [y/N] " confirm
	case "$confirm" in
		[Yy]*) ;;
		*) echo "Aborting."; exit 1 ;;
	esac
fi

step 2 "Loading the Oracle environment for '$sid'..."
export ORACLE_SID="$sid"
export ORAENV_ASK=NO
oraenv_output=$(. oraenv -s 2>&1)
oraenv_status=$?
if [ $oraenv_status -ne 0 ]; then
	echo "Failed to load the Oracle environment for ORACLE_SID=$sid:"
	echo "$oraenv_output"
	exit 1
fi

if ! command -v sqlplus >/dev/null 2>&1; then
	echo "sqlplus not found on PATH after sourcing oraenv. Check your Oracle environment."
	exit 1
fi
echo "Using ORACLE_HOME=$ORACLE_HOME"

timestamp=$(date +%d%m%y%H%M)
work_dir="/tmp/awrdata_${sid}_${timestamp}"
result_file="/tmp/awr.${sid}.${timestamp}.tar.gz"
sqlopt="set pagesize 0 feedback off heading off echo off verify off trimspool on linesize 32767"

mkdir -p "$work_dir"
cd "$work_dir" || exit 1

step 3 "Connecting to '$sid' and identifying the database..."
dbinfo=$(sqlplus -s / as sysdba <<EOF
$sqlopt
select d.dbid || '|' || i.instance_number || '|' || d.name || '|' || i.instance_name
from v\$database d, v\$instance i;
exit;
EOF
)
dbid=$(echo "$dbinfo" | cut -d'|' -f1 | tr -d '[:space:]')
instnum=$(echo "$dbinfo" | cut -d'|' -f2 | tr -d '[:space:]')
dbname=$(echo "$dbinfo" | cut -d'|' -f3 | tr -d '[:space:]')

if [ -z "$dbid" ]; then
	echo "Could not connect as sysdba to $sid. Check your Oracle environment and permissions."
	echo "sqlplus said:"
	echo "$dbinfo"
	cd /tmp && rm -rf "$work_dir"
	exit 1
fi
echo "Connected to database $dbname (dbid=$dbid)."

step 4 "Determining the available AWR snapshot range..."
snapinfo=$(sqlplus -s / as sysdba <<EOF
$sqlopt
select min(snap_id) || '|' || max(snap_id) from dba_hist_snapshot where dbid = $dbid;
exit;
EOF
)
minsnap=$(echo "$snapinfo" | cut -d'|' -f1 | tr -d '[:space:]')
maxsnap=$(echo "$snapinfo" | cut -d'|' -f2 | tr -d '[:space:]')

if [ -z "$minsnap" ] || [ -z "$maxsnap" ] || [ "$minsnap" = "$maxsnap" ]; then
	echo "Fewer than two AWR snapshots are available for $dbname. Nothing to report yet."
	echo "(AWR needs at least two snapshots to generate a report between them.)"
	cd /tmp && rm -rf "$work_dir"
	exit 1
fi

snaptimes=$(sqlplus -s / as sysdba <<EOF
$sqlopt
select to_char(begin_interval_time,'DD-MON-YYYY HH24:MI') from dba_hist_snapshot where dbid=$dbid and snap_id=$minsnap;
select to_char(begin_interval_time,'DD-MON-YYYY HH24:MI') from dba_hist_snapshot where dbid=$dbid and snap_id=$maxsnap;
exit;
EOF
)
firsttime=$(echo "$snaptimes" | sed -n '1p' | xargs)
lasttime=$(echo "$snaptimes" | sed -n '2p' | xargs)
echo "Found snapshots $minsnap ($firsttime) through $maxsnap ($lasttime)."

step 5 "Generating AWR reports for that range (this is the slow step, be patient)..."
sqlplus -s / as sysdba <<EOF > /dev/null
$sqlopt
set serverout on size unlimited
spool my_awr_report.sql
prompt set heading off feedback off linesize 800 pagesize 5000 trimspool on trimout on termout off
DECLARE
  c_dbid CONSTANT NUMBER := $dbid;
  c_start_snap_id CONSTANT NUMBER := $minsnap;
  c_end_snap_id CONSTANT NUMBER := $maxsnap;
  v_awr_reportname VARCHAR2(100);
  CURSOR c_snapshots IS
    select inst_num, start_snap_id, end_snap_id
    from (
      select s.instance_number as inst_num,
             s.snap_id as start_snap_id,
             lead(s.snap_id,1,null) over (partition by s.instance_number order by s.snap_id) as end_snap_id
      from dba_hist_snapshot s
      where s.dbid = c_dbid and s.snap_id >= c_start_snap_id and s.snap_id <= c_end_snap_id
    )
    where end_snap_id is not null
    order by inst_num, start_snap_id;
BEGIN
  FOR cr IN c_snapshots LOOP
    v_awr_reportname := 'awrrpt_'||cr.inst_num||'_'||cr.start_snap_id||'_'||cr.end_snap_id||'.html';
    dbms_output.put_line('spool '||v_awr_reportname);
    dbms_output.put_line('select output from table(dbms_workload_repository.awr_report_html('||c_dbid||','||cr.inst_num||','||cr.start_snap_id||','||cr.end_snap_id||',0));');
    dbms_output.put_line('spool off');
  END LOOP;
END;
/
spool off
@my_awr_report.sql
exit;
EOF

report_count=$(find . -maxdepth 1 -name 'awrrpt_*.html' | wc -l | tr -d '[:space:]')
if [ "$report_count" -eq 0 ]; then
	echo "No AWR reports were generated. Check the Oracle environment and try again."
	cd /tmp && rm -rf "$work_dir"
	exit 1
fi
echo "Generated $report_count AWR report(s)."

step 6 "Packaging results into a single archive..."
rm -f "$work_dir/my_awr_report.sql"
cd /tmp || exit 1
tar -czf "$result_file" -C /tmp "$(basename "$work_dir")"
rm -rf "$work_dir"

echo ""
echo "Data collection complete for $sid ($dbname)."
echo "Upload $result_file to https://upload.davidkentconsulting.com/"
echo "and describe it as AWR data for $dbname, covering $firsttime to $lasttime."
echo ""
echo "Run this script again for any other database that needs AWR data collected."
