This is the README.md file for the git repository David-Kent-Consulting/workload_collection_scripts.

PURPOSE
=======
The purpose of this git repository is to have a common repository for data
collection scripts that are commonly used for determining existing workloads
for Fedora Linux hosts and databases. The only database we consider for
data collection at the time of the most recent push is Oracle Database
version 12x or later.

LICENSE REQUIREMENTS
====================
The repository is open to the community and is considered open source under the
GNU General Public License Agreement. The programs contained herein are free software;
you can redistribute it and/or modify them under the terms of the GNU General Public
License as published by the Free Software Foundation; either version 2 of the License,
or (at your option) any later version. If you update these files, you can contact us
on the public git repository and we will be more than happy to incorporate your
improvements if considered applicable to the purpose of this repository.

FILES CURRENTLY IN THIS REPOSITORY
==================================
1. awr_generator.sql - Many Oracle DBAs are already familiar with this script. It
   was originally authored by "flashdba" in 2014. It is a great work for which we
   see no reason to modify except that we change the output name and the default
   file format to HTML.
2. collect_perf_data.ksh - This utility collects granular data from several kernel
   reporting tools. It was originally authored by Hank Wojteczko for Solaris and
   AIX, but has been modified for Fedora Linux version 7.x or later. Removed from
   the original script is data collection from the vnet interface since this is
   not considered useful in today's modern cloud infrastructure.
3. sql_loadtest_scripts - These scripts are used to load test a DB system. They
   should not be used on a production system without authorization since.
   Running the load test scripts on a production system WILL BE disruptive. We
   recommend the scripts be run by a qualified DBA when standing up a new DB
   system or if analyzing an existing DB system during an approved outage window.
   These scripts are provided as is. Run them at your own risk.

INSTRUCTIONS FOR USE OF AWR COLLECTION SCRIPT
=============================================
See the instructions embedded within the utility collect_perf_data.ksh for the
correct use of the utility. The remainder of the instructions are for the
utility awr_generator.sql.

WARNING! You must have the awrinput.sql and other supporting scripts installed
within your $ORACLE_HOME in order for this script to run.

1. Copy the utility to the Oracle service user's home directory within a subdirectory.
   This is the best practice since the utility will create a copious number of files
   that you will not want to clutter up other directories. Or, you could copy the file
   to /usr/local/bin or another directory and directly call it within the subdirectory
   into which you wish to creater the AWR reports.
2. Make sure both your $ORACLE_HOME and $ORACLE_BASE are correctly set by oraenv. This
   utility will not behave as expected in the absence of the above environment
   variables.
3. Set your environment with .oraenv and enter your ORACLE SID name.
4. Enter SQL with 'sqlplus / as sysdba'
5. Call the script with @awr_generator.sql
6. You will be prompted for the number of days to collect data for. We recommend that
   you collect 30 days of AWR SNAPS. Note however you will only be able to collect 30
   days of SNAPS if you have defined the SNAP retention value as such. Burleson has
   an excellent book about Oracle performance tuning and AWR if this is new material
   for you. See https://www.amazon.com/Oracle-High-Performance-Tuning-Donald-Burleson/dp/0072190582
7. You will see a long list of AWR SNAPs. Select the lowest AWR SNAP number in the list.
8. Next enter the last AWR SNAP number.
9. The script will end and you will be returned to the SQL prompt. Also, you will be
    told the name of the output script that should be runned next, which will be
    my_awr_report.sql. Run the script as in '@my_awr_report.sql'
10. Now watch it run. This will take sometime to complete. Each AWR SNAP set will
   consume about 1MB of disk storage. You'll need about 2GB of storage for 30 days
   of SNAP reports, which includes storage needed for the next task.
11. The utility will exit to the SQL prompt. Quite sqlplus.
12. We recommend that you tar up the HTML files, and then compress with gzip. Then
    remove the HTML files from the directory.
13. Finally, copy your compressed file to your local system. Be sure to remove the
    source file from the DB host since it serves no purpose to leave it there.
14. Finally, upload the compressed tar file to the project folder (if you are working
    with one of our cloud experts) or extract the files and begin your own analysis.

OTHER SQL SCRIPTS INCLUDED IN THIS REPOSITORY
=============================================

**check_tablespace_utilization.sql**

Reports tablespace utilization of all tables within the PDB

**check_tmp_table_space_utilization.sql**

Reports utilization in TEMP tablespace within the PDB

**database_wait_time_ratio.sql**

Reports the database wait time and CPU time ratios for the CDB

**intensive_disk_read_queries.sql**

Reports the top IO read running queries for the CDB

**redo_generated_by_session.sql**

Reports redos generated by session for the CDB

**sql_ordered_by_cpu_usage.sql**

Reports in order the top running queries by CPU consumption within the CDB

**top_10_long_running_queries.sql**
Reports the top 10 long running queries, and then prompts for an SQL ID and child number to get the full SQL query

**wait_class_and_their_waiting_time.sql**

Reports general system information

**waiting_events_and_session_details.sql**

Reports by SID, USERNAME, EVENT, MACHINE, STATE, SQL ID, Partial SQL statement Minutes + Seconds and stats of running SQL statements.
