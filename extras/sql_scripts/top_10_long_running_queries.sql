column column_name format a30
set linesize 300

SELECT * FROM
(SELECT
    sql_fulltext,
    sql_id,
    elapsed_time,
    child_number,
    disk_reads,
    executions,
    first_load_time,
    last_load_time
FROM    v$sql
ORDER BY elapsed_time DESC)
WHERE ROWNUM < 10
/

SELECT * FROM table(DBMS_XPLAN.DISPLAY_CURSOR('&sql_id', &child));
