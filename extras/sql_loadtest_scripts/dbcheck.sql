--- SQL script dbcheck.sql
--- called by dbcheck.py and run against the CDB instance.

WHENEVER sqlerror EXIT sql.sqlcode;
SET feedback off linesize 255 pages 1000;

PROMPT;
PROMPT HEALTH REPORT FOR DATABASE TEST01;
PROMPT Database open status below;
PROMPT
SELECT instance_name, status, database_status FROM v$instance;
PROMPT

PROMPT Active User Sessions;
SELECT count(1) FROM v$session WHERE status='ACTIVE';
PROMPT

PROMPT ^^^^^^^^^^^^^^^^^^^^^^;
PROMPT RECENT RMAN BACKUP OPERATIONS:;
PROMPT ^^^^^^^^^^^^^^^^^^^^^^;
col START_TIME for a15;
col END_TIME for a15;
col TIME_TAKEN_DISPLAY for a10;
col INPUT_BYTES_DISPLAY heading "DATA SIZE" for a10;
col OUTPUT_BYTES_DISPLAY heading "Backup Size" for a11
col OUTPUT_BYTES_PER_SEC_DISPLAY heading "Speed/s" for a10;
col output_device_type heading "Device_TYPE" for a11;
SELECT to_char (start_time,'DD-MON-YY HH24:MI') START_TIME,
   to_char(end_time,'DD-MON-YY HH24:MI') END_TIME,
   time_taken_display,
   status,
   input_type,
   output_device_type,
   input_bytes_display,
   output_bytes_display,
   output_bytes_per_sec_display,
   COMPRESSION_RATIO
FROM v$rman_backup_job_details WHERE end_time > sysdate -37;
PROMPT
PROMPT

col INITIAL_ALLOCATION for a20;
col LIMIT_VALUE for a20;
select * from gv$resource_limit order by RESOURCE_NAME;
PROMPT
PROMPT


PROMPT REDO LOG SWITCHES:;
PROMPT ^^^^^^^^^^^^^^^^^^;
col day for a11;
SELECT to_char(first_time,'YYYY-MON-DD') day,
   to_char(sum(decode(to_char(first_time,'HH24'),'00',1,0)),'9999') "00",
   to_char(sum(decode(to_char(first_time,'HH24'),'01',1,0)),'9999') "01",
   to_char(sum(decode(to_char(first_time,'HH24'),'02',1,0)),'9999') "02",
   to_char(sum(decode(to_char(first_time,'HH24'),'03',1,0)),'9999') "03",
   to_char(sum(decode(to_char(first_time,'HH24'),'04',1,0)),'9999') "04",
   to_char(sum(decode(to_char(first_time,'HH24'),'05',1,0)),'9999') "05",
   to_char(sum(decode(to_char(first_time,'HH24'),'06',1,0)),'9999') "06",
   to_char(sum(decode(to_char(first_time,'HH24'),'07',1,0)),'9999') "07",
   to_char(sum(decode(to_char(first_time,'HH24'),'08',1,0)),'9999') "08",
   to_char(sum(decode(to_char(first_time,'HH24'),'09',1,0)),'9999') "09",
   to_char(sum(decode(to_char(first_time,'HH24'),'10',1,0)),'9999') "10",
   to_char(sum(decode(to_char(first_time,'HH24'),'11',1,0)),'9999') "11",
   to_char(sum(decode(to_char(first_time,'HH24'),'12',1,0)),'9999') "12",
   to_char(sum(decode(to_char(first_time,'HH24'),'13',1,0)),'9999') "13",
   to_char(sum(decode(to_char(first_time,'HH24'),'14',1,0)),'9999') "14",
   to_char(sum(decode(to_char(first_time,'HH24'),'15',1,0)),'9999') "15",
   to_char(sum(decode(to_char(first_time,'HH24'),'16',1,0)),'9999') "16",
   to_char(sum(decode(to_char(first_time,'HH24'),'17',1,0)),'9999') "17",
   to_char(sum(decode(to_char(first_time,'HH24'),'18',1,0)),'9999') "18",
   to_char(sum(decode(to_char(first_time,'HH24'),'19',1,0)),'9999') "19",
   to_char(sum(decode(to_char(first_time,'HH24'),'20',1,0)),'9999') "20",
   to_char(sum(decode(to_char(first_time,'HH24'),'21',1,0)),'9999') "21",
   to_char(sum(decode(to_char(first_time,'HH24'),'22',1,0)),'9999') "22",
   to_char(sum(decode(to_char(first_time,'HH24'),'23',1,0)),'9999') "23"
FROM v$log_history WHERE first_time > sysdate-1
GROUP BY to_char(first_time,'YYYY-MON-DD') ORDER BY 1 ASC;
PROMPT
PROMPT



exit;
