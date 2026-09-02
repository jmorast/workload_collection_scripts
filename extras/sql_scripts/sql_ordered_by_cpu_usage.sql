rem
 rem SQL by CPU Usage (v$sqlarea)
 rem
 column sql_text format a40 word_wrapped heading 'SQL|Text'
 column cpu_time heading 'CPU|Time'
 column elapsed_time heading 'Elapsed|Time'
 column disk_reads heading 'Disk|Reads'
 column buffer_gets heading 'Buffer|Gets'
 column rows_processed heading 'Rows|Processed'
 set pages 55 lines 132
 --ttitle 'SQL By CPU Usage'
 prompt
 prompt +----------------------------------------------------+
 prompt | SQL BY CPU USAGE
 prompt +----------------------------------------------------+
 select * from
 (select sql_text,sql_id,
 cpu_time/1000000 cpu_time,
 elapsed_time/1000000 elapsed_time,
 disk_reads,
 buffer_gets,
 rows_processed
 from v$sqlarea
 order by cpu_time desc, disk_reads desc
 )
 where rownum < 10
 /
