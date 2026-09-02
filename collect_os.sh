#!/bin/bash

# Collects OS-level workload data (CPU, memory, disk I/O) for a David Kent
# Consulting cloud engagement. Run this on every host you need workload data
# for. It runs unattended for 72 hours, then packages everything into a
# single .tar.gz in /tmp for you to upload.
#
# Originally authored by Hank Wojteczko for Solaris/AIX, adapted for Linux.
#
# LICENSE
# =======
# Free software under the GNU General Public License v2 (or later). See
# https://www.gnu.org/licenses/gpl-2.0.html
#
# REQUIREMENTS
# ============
# - sysstat (for iostat)
# - tar, gzip
#
# HOW TO RUN
# ==========
# Start this on a Monday, Tuesday, or Wednesday morning unless your cloud
# engineer has told you otherwise, so the 72-hour window captures a normal
# business cycle. Background it so it survives you logging out:
#
#   nohup ./collect_os.sh > /tmp/collect_os.log 2>&1 &
#
# When it finishes, it prints the path to a single .tar.gz. Upload that file
# to https://upload.davidkentconsulting.com/ and describe it as OS workload
# data for this host, with the date range it covers.

set -u

iterations=43200
interval=6
timestamp=$(date +%d%m%y%H%M)
out_dir="/tmp/perfdata_${timestamp}"
result_file="/tmp/perfdata.${timestamp}.tar.gz"

echo "Checking system requirements..."

if ! command -v iostat >/dev/null 2>&1; then
	echo "This script requires the sysstat package (for iostat)."
	echo "Install as root with: yum install sysstat -y"
	exit 1
fi
if ! command -v tar >/dev/null 2>&1; then
	echo "This script requires tar. Please install it and try again."
	exit 1
fi
if ! command -v gzip >/dev/null 2>&1; then
	echo "This script requires gzip. Please install it and try again."
	exit 1
fi

mkdir -p "$out_dir"

echo "Starting vmstat and iostat for $iterations iterations of ${interval}s each..."
vmstat $interval $iterations > "$out_dir/vmstat.${timestamp}.txt" &
iostat -x $interval $iterations > "$out_dir/iostat.${timestamp}.txt" &

cat /proc/cpuinfo > "$out_dir/cpuinfo.${timestamp}.txt"

echo "Collecting memory/swap stats every ${interval}s. This will run for about 72 hours."
counter=0
while [ $counter -lt $iterations ]; do
	{
		echo "------------"
		echo "iteration $counter"
		grep -E 'MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree' /proc/meminfo
	} >> "$out_dir/meminfo.${timestamp}.txt"
	counter=$((counter + 1))
	sleep $interval
done

wait

echo "Packaging results..."
tar -C /tmp -czf "$result_file" "$(basename "$out_dir")"
rm -rf "$out_dir"

echo ""
echo "Data collection complete."
echo "Upload $result_file to https://upload.davidkentconsulting.com/"
echo "and describe it as OS workload data for this host."
