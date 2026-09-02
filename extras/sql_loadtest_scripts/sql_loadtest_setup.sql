-- Original script can be found at https://use-the-index-luke.com/sql/example-schema/oracle/performance-testing-scalability
-- RUN AT YOUR OWN RISK

-- This script sets up the store procedures for a load test. Manually remove these procedures
-- from the database after your load test is complete.

CREATE OR REPLACE PACKAGE test_scalability IS
  TYPE piped_output IS RECORD ( section  NUMBER
                              , seconds  NUMBER
                              , cnt_rows NUMBER);
  TYPE piped_output_table IS TABLE OF piped_output;

  FUNCTION run(sql_txt IN varchar2, n IN number)
    RETURN test_scalability.piped_output_table PIPELINED;
END;
/

CREATE OR REPLACE PACKAGE BODY test_scalability
IS
  TYPE tmp IS TABLE OF piped_output INDEX BY PLS_INTEGER;

  FUNCTION run(sql_txt IN VARCHAR2, n IN NUMBER)
    RETURN test_scalability.piped_output_table PIPELINED
  IS
    rec  test_scalability.tmp;
    r    test_scalability.piped_output;
    iter NUMBER;
    sec  NUMBER;
    strt NUMBER;
    exec_txt VARCHAR2(4000);
    cnt  NUMBER;
  BEGIN
    exec_txt := 'select count(*) from (' || sql_txt || ')';
    iter := 0;
    WHILE iter <= n LOOP
      sec := 0;
      WHILE sec < 300 LOOP
        IF iter = 0 THEN
           rec(sec).seconds  := 0;
           rec(sec).section  := sec;
           rec(sec).cnt_rows := 0;
        END IF;
        strt := DBMS_UTILITY.GET_TIME;
        EXECUTE IMMEDIATE exec_txt INTO cnt USING sec;
        rec(sec).seconds := rec(sec).seconds 
                          + (DBMS_UTILITY.GET_TIME - strt)/100;
        rec(sec).cnt_rows:= rec(sec).cnt_rows + cnt;
        IF iter = n THEN
          PIPE ROW(rec(sec));
        END IF;
        sec := sec +1;
      END LOOP;
      iter := iter +1;
    END LOOP;
    RETURN;
  END;
END test_scalability;
/
