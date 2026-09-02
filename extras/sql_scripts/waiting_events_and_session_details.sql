column column_name format a30
set linesize 300


col sql format a35
 col username format a20
 col child format 999
 col secs format 9999
 col machine format a12
 col event format a25
 col state format a10
 select /*+ rule */ distinct
 w.sid,s.username,substr(w.event,1,25) event,substr(s.machine,1,12) machine,substr(w.state,1,10) state,s.SQL_ID,--q.CHILD_NUMBER CHILD,
 substr(q.sql_text,1,33) "SQL",round(s.LAST_CALL_ET/60) "MINS", round(s.LAST_CALL_ET) "Sec"
 from gv$session_wait w,gv$session s,gv$sql q where w.event like '%&event%'
 and w.sid=s.sid
 and s.SQL_HASH_VALUE=q.HASH_VALUE(+)
 and s.status='ACTIVE'
 and s.username is not null
 and substr(w.event,1,25) not like 'SQL*Net message from clie%'
 order by "MINS"
 /
