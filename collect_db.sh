#!/bin/bash

# Collects Oracle AWR workload data for a David Kent Consulting cloud
# engagement, in one pass across every running database on this host.
#
# You'll be asked which database should get the FULL AWR history treatment
# (every retained snapshot, one HTML report per hour) -- pick the "heavy
# hitter" the engagement actually cares about. Every OTHER currently
# running database automatically gets a lighter single report covering
# just its most recent hour, as a spot-check. Each database produces its
# own .tar.gz in /tmp.
#
# AWR report generation logic adapted from awr-generator.sql, originally
# authored by flashdba (http://flashdba.com, 2014) and modified by
# hankwojteczko@davidkentconsulting.com. See extras/sql_scripts/awr_generator.sql
# for the original, interactive version.
#
# REQUIREMENTS
# ============
# - Run as (or su to) the Oracle software owner (usually the "oracle" OS user).
# - Every target database must be Oracle Enterprise Edition with the
#   Diagnostic Pack license. AWR is a licensed feature -- confirm the client
#   is licensed for it before running this.
# - oraenv must be on your PATH (standard on any Oracle install).
# - tar, gzip.
#
# HOW TO RUN
# ==========
#   ./collect_db.sh
# or non-interactively, naming which database gets the full treatment:
#   ./collect_db.sh <ORACLE_SID>
#
# When it finishes, it prints a summary of every .tar.gz it produced.
# Upload each one to https://upload.davidkentconsulting.com/ and describe
# which database and date range it covers.

set -u

results=()
failures=()

step() {
	# args: sid  step_num  total_steps  message
	echo ""
	echo "[$1][$2/$3] $4"
}

discover_running_sids() {
	# Capture the ps snapshot into a variable FIRST, before running any
	# parsing commands -- otherwise a live "ps | awk" pipeline can catch its
	# own awk process in the snapshot, since the -F separator argument
	# literally contains the search text "ora_pmon_".
	local ps_snapshot
	ps_snapshot=$(ps -ef)
	echo "$ps_snapshot" | awk -F'ora_pmon_' '/ora_pmon_/{print $2}' | sort -u
}

# collect_one_sid <sid> <mode: full|recent> <confirm_if_unknown: yes|no>
# mode "full"   -- every retained snapshot, one report per hour
# mode "recent" -- a single report covering just the most recent snapshot pair
collect_one_sid() {
	local sid="$1" mode="$2" confirm_if_unknown="$3"
	local total_steps=6

	step "$sid" 1 "$total_steps" "Validating ORACLE_SID..."
	local oratab="/etc/oratab"
	if [ -f "$oratab" ] && ! grep -Eq "^${sid}:" "$oratab"; then
		if [ "$confirm_if_unknown" = "yes" ]; then
			echo "'$sid' was not found in $oratab. SIDs registered on this host:"
			grep -Ev '^#|^$' "$oratab" | cut -d: -f1 | sed 's/^/  - /'
			read -rp "Continue anyway with SID '$sid'? [y/N] " confirm
			case "$confirm" in
				[Yy]*) ;;
				*) echo "Skipping $sid."; failures+=("$sid -- not in $oratab, skipped"); return 1 ;;
			esac
		else
			echo "'$sid' was not found in $oratab, skipping it."
			failures+=("$sid -- not in $oratab, skipped")
			return 1
		fi
	fi

	step "$sid" 2 "$total_steps" "Loading the Oracle environment..."
	export ORACLE_SID="$sid"
	export ORAENV_ASK=NO
	local oraenv_output oraenv_status
	oraenv_output=$(. oraenv -s 2>&1)
	oraenv_status=$?
	if [ $oraenv_status -ne 0 ]; then
		echo "Failed to load the Oracle environment for ORACLE_SID=$sid:"
		echo "$oraenv_output"
		failures+=("$sid -- could not load Oracle environment")
		return 1
	fi

	if ! command -v sqlplus >/dev/null 2>&1; then
		echo "sqlplus not found on PATH after sourcing oraenv. Check your Oracle environment."
		failures+=("$sid -- sqlplus not found")
		return 1
	fi
	echo "Using ORACLE_HOME=$ORACLE_HOME"

	local timestamp work_dir result_file sqlopt
	timestamp=$(date +%d%m%y%H%M%S)
	work_dir="/tmp/awrdata_${sid}_${timestamp}"
	result_file="/tmp/awr.${sid}.${timestamp}.tar.gz"
	sqlopt="set pagesize 0 feedback off heading off echo off verify off trimspool on linesize 32767"

	mkdir -p "$work_dir"
	cd "$work_dir" || { failures+=("$sid -- could not create work dir"); return 1; }

	step "$sid" 3 "$total_steps" "Connecting and identifying the database..."
	local dbinfo dbid dbname
	dbinfo=$(sqlplus -s / as sysdba <<EOF
$sqlopt
select d.dbid || '|' || i.instance_number || '|' || d.name || '|' || i.instance_name
from v\$database d, v\$instance i;
exit;
EOF
	)
	dbid=$(echo "$dbinfo" | cut -d'|' -f1 | tr -d '[:space:]')
	dbname=$(echo "$dbinfo" | cut -d'|' -f3 | tr -d '[:space:]')

	if [ -z "$dbid" ]; then
		echo "Could not connect as sysdba to $sid. Check your Oracle environment and permissions."
		echo "sqlplus said:"
		echo "$dbinfo"
		cd /tmp && rm -rf "$work_dir"
		failures+=("$sid -- could not connect as sysdba")
		return 1
	fi
	echo "Connected to database $dbname (dbid=$dbid)."

	step "$sid" 4 "$total_steps" "Determining the AWR snapshot range ($mode)..."
	local snapquery
	if [ "$mode" = "full" ]; then
		snapquery="select min(snap_id) || '|' || max(snap_id) from dba_hist_snapshot where dbid = $dbid;"
	else
		snapquery="select listagg(snap_id,'|') within group (order by snap_id) from (select snap_id from dba_hist_snapshot where dbid = $dbid order by snap_id desc fetch first 2 rows only);"
	fi

	local snapinfo minsnap maxsnap
	snapinfo=$(sqlplus -s / as sysdba <<EOF
$sqlopt
$snapquery
exit;
EOF
	)
	minsnap=$(echo "$snapinfo" | cut -d'|' -f1 | tr -d '[:space:]')
	maxsnap=$(echo "$snapinfo" | cut -d'|' -f2 | tr -d '[:space:]')

	if [ -z "$minsnap" ] || [ -z "$maxsnap" ] || [ "$minsnap" = "$maxsnap" ]; then
		echo "Fewer than two AWR snapshots are available for $dbname. Nothing to report yet."
		echo "(AWR needs at least two snapshots to generate a report between them.)"
		cd /tmp && rm -rf "$work_dir"
		failures+=("$sid ($dbname) -- fewer than two AWR snapshots available")
		return 1
	fi

	local snaptimes firsttime lasttime
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

	step "$sid" 5 "$total_steps" "Generating AWR report(s) for that range (be patient)..."
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

	local report_count
	report_count=$(find . -maxdepth 1 -name 'awrrpt_*.html' | wc -l | tr -d '[:space:]')
	if [ "$report_count" -eq 0 ]; then
		echo "No AWR reports were generated for $sid. Check the Oracle environment and try again."
		cd /tmp && rm -rf "$work_dir"
		failures+=("$sid ($dbname) -- no reports generated")
		return 1
	fi
	echo "Generated $report_count AWR report(s)."

	step "$sid" 6 "$total_steps" "Packaging results into a single archive..."
	rm -f "$work_dir/my_awr_report.sql"
	cd /tmp || return 1
	tar -czf "$result_file" -C /tmp "$(basename "$work_dir")"
	rm -rf "$work_dir"

	echo "Done: $result_file ($dbname, $firsttime to $lasttime)"
	results+=("$result_file -- $sid ($dbname), $firsttime to $lasttime")
	return 0
}

main_sid_arg="${1:-}"

running_sids=$(discover_running_sids)

if [ -z "$running_sids" ]; then
	echo "No running Oracle instances detected (looked for ora_pmon_* processes)."
	echo ""
	full_sid="$main_sid_arg"
	if [ -z "$full_sid" ]; then
		read -rp "Enter the ORACLE_SID to collect full AWR history for: " full_sid
	fi
else
	echo "Currently running Oracle instances on this host:"
	echo "$running_sids" | sed 's/^/  - /'
	echo ""
	full_sid="$main_sid_arg"
	if [ -z "$full_sid" ]; then
		read -rp "Which database gets the FULL AWR history treatment? (every other running database above gets a single most-recent-hour report): " full_sid
	fi
fi

if [ -z "$full_sid" ]; then
	echo "No ORACLE_SID given, exiting."
	exit 1
fi

other_sids=$(echo "$running_sids" | grep -Fvx "$full_sid" || true)

echo ""
echo "=== Full AWR history: $full_sid ==="
collect_one_sid "$full_sid" full yes

if [ -n "$other_sids" ]; then
	while IFS= read -r sid; do
		[ -z "$sid" ] && continue
		echo ""
		echo "=== Most-recent-hour AWR: $sid ==="
		collect_one_sid "$sid" recent no
	done <<< "$other_sids"
else
	echo ""
	echo "No other running databases detected -- nothing else to collect."
fi

echo ""
echo "================ SUMMARY ================"
if [ ${#results[@]} -eq 0 ]; then
	echo "No AWR archives were produced."
else
	printf '%s\n' "${results[@]}"
fi
if [ ${#failures[@]} -gt 0 ]; then
	echo ""
	echo "Skipped or failed:"
	printf '%s\n' "${failures[@]}"
fi
echo ""
echo "Upload each .tar.gz above to https://upload.davidkentconsulting.com/,"
echo "describing which database and date range it covers."
