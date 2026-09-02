rem WARNING! This will generate a lot of read IO for a brief period of time.
rem Run this script during quite times or non-business hours

set line 1000;
 col file_id for a6;
 col file_name for a55;
 col TABLESPACE_NAME for a30;
 set pagesize 128;
 set feedback off;
 select  a.TABLESPACE_NAME,
        a.BYTES/1024/1024/1024 GB_used,
        b.BYTES/1024/1024/1024 GB_free,
        b.largest,
        round(((a.BYTES-b.BYTES)/a.BYTES)*100,2) percent_used
 from
        (
                select  TABLESPACE_NAME,
                        sum(BYTES) BYTES
                from    dba_data_files
                group   by TABLESPACE_NAME
        )
        a,
        (
                select  TABLESPACE_NAME,
                        sum(BYTES) BYTES ,
                        max(BYTES) largest
                from    dba_free_space
                group   by TABLESPACE_NAME
        )
        b
 where   a.TABLESPACE_NAME=b.TABLESPACE_NAME
 order   by ((a.BYTES-b.BYTES)/a.BYTES) desc;

