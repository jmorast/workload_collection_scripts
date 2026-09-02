SET LINESIZE 145
 SET PAGESIZE 9999
 COLUMN wait_class        FORMAT a20              HEADING 'WAIT_CLASS'
 COLUMN inst_id           FORMAT 99               HEADING 'INST_ID'          JUSTIFY right
 COLUMN BEGIN_TIME        FORMAT 9999999          HEADING 'BEGIN_TIME'         JUSTIFY left
 COLUMN end_time          FORMAT 9999999          HEADING 'END_TIME'             JUSTIFY left
 COLUMN dbtime_in_wait    FORMAT 9999.99          HEADING 'DBTIME_IN_WAIT'     JUSTIFY right
 COLUMN time_waited       FORMAT 9999999.99          HEADING 'TIME_WAITED'        JUSTIFY right
 prompt
 prompt +----------------------------------------------------+
 prompt | The waits are from which wait classes|
 prompt +----------------------------------------------------+
 select b.wait_class ,a.inst_id ,a.begin_time ,
 a.end_time , a.dbtime_in_wait , a.time_waited from GV$WAITCLASSMETRIC a , gV$SYSTEM_WAIT_CLASS b where
 a.wait_class_id = b.wait_class_id
 and  a.inst_id =1
 and a.inst_id = b.inst_id
 --- and b.wait_class='Commit'
 order by 5 desc ;
