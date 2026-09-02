SET LINESIZE 1000
 SET PAGESIZE 1000
 COLUMN metric_name       FORMAT a40              HEADING 'METRIC_NAME'
 COLUMN metric_unit       FORMAT a30           HEADING 'METRIC_UNIT'
 COLUMN inst_id           FORMAT 99               HEADING 'inst_id'          JUSTIFY right
 COLUMN intsize_csec      FORMAT 999999999.99              HEADING 'INTSIZE_CSEC'     JUSTIFY right
 COLUMN VALUE             FORMAT 999999999.99               HEADING 'VALUE'        JUSTIFY right
 COLUMN BEGIN_TIME        FORMAT 9999999          HEADING 'begin_time'         JUSTIFY right
 COLUMN end_time          FORMAT a20              HEADING 'end_time' TRUNC
 prompt
 prompt +----------------------------------------------------+
 prompt | Validating the Database and Wait Time ratio  |
 prompt +----------------------------------------------------+
 select  METRIC_NAME,metric_unit,INST_ID,INTSIZE_CSEC,
        VALUE,begin_time ,end_time
 from    GV$SYSMETRIC
 where   METRIC_NAME IN ('Database CPU Time Ratio',
                        'Database Wait Time Ratio')
                        AND
        (INTSIZE_CSEC ,inst_id ) in
        (select max(INTSIZE_CSEC),inst_id  from GV$SYSMETRIC group by inst_id )   order by 3 ;
