-- Original script can be found at https://use-the-index-luke.com/sql/example-schema/oracle/performance-testing-scalability
-- RUN AT YOUR OWN RISK


CREATE TABLE scala_data_01 (
   section NUMBER NOT NULL,
   id1     NUMBER NOT NULL,
   id2     NUMBER NOT NULL
);

INSERT INTO scala_data_01
SELECT sections.n, gen.x, CEIL(DBMS_RANDOM.VALUE(0, 100)) 
  FROM (
         SELECT level - 1 n
           FROM DUAL
        CONNECT BY level < 300) sections
       , (
         SELECT level x
           FROM DUAL
        CONNECT BY level < 900000) gen
 WHERE gen.x <= sections.n * 3000;

 CREATE INDEX scale_slow ON scala_data_01 (section, id1, id2);


BEGIN
     DBMS_STATS.GATHER_TABLE_STATS(null, 'scala_data_01' 
                                       , CASCADE => true);
END;
/


SELECT *
  FROM TABLE(test_scalability.run(
       'SELECT * ' 
      || 'FROM scala_data_01 '
      ||'WHERE section=:1 '
      ||  'AND id2=CEIL(DBMS_RANDOM.value(1,100))', 10));

DROP INDEX scale_slow;
CREATE INDEX scale_fast ON scala_data_01 (section, id2, id1);


BEGIN
     DBMS_STATS.GATHER_TABLE_STATS(null, 'scala_data_01' 
                                       , CASCADE => true);
END;
/

SELECT *
  FROM TABLE(test_scalability.run(
       'SELECT * ' 
      || 'FROM scala_data_01 '
      ||'WHERE section=:1 '
      ||  'AND id2=CEIL(DBMS_RANDOM.value(1,10))', 10));

DROP TABLE scala_data_01;
