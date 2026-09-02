set linesize 300;

SELECT user_id,module,plsql_object_id,plsql_subprogram_id,sql_id,COUNT(*) cpu_secs
FROM v$active_session_history
WHERE event IS NULL -- on CPU
    AND sample_time BETWEEN TO_DATE('03/25/2024 12:30:00','MM/DD/YYYY HH24:MI:SS') AND TO_DATE('03/25/2024 12:45:00','MM/DD/YYYY HH24:MI:SS')
GROUP BY user_id,module,plsql_object_id,plsql_subprogram_id,sql_id
ORDER BY COUNT(*) DESC;
