SET parallel_replicas_local_plan=1;

DROP TABLE IF EXISTS t1;
DROP TABLE IF EXISTS t2;
DROP TABLE IF EXISTS t3;
DROP TABLE IF EXISTS t4;

CREATE TABLE t1 (id UInt32, name String) ENGINE = Memory;
CREATE TABLE t2 (arr Array(UInt32), value String) ENGINE = Memory;

INSERT INTO t1 VALUES (1, 'Alice'), (2, 'Bob'), (3, 'Charlie');
INSERT INTO t2 VALUES ([1, 2], 'A'), ([2, 3], 'B'), ([3], 'A');

--- not working start

DROP TABLE IF EXISTS t10;
CREATE TABLE t10 (arr Array(Nullable(UInt32)), value String) ENGINE = Memory;
INSERT INTO t10 VALUES ([1, NULL, 2], 'WithNull');

select 't1';
select * from t1;
select 't10';
select * from t10;

select 'new';
SELECT t1.id, t10.value
FROM t1
         INNER JOIN t10 ON has(t10.arr, t1.id)
--where t1.id > 0
ORDER BY t1.id
    SETTINGS enable_analyzer = 0;

select 'old';
SELECT t1.id, t10.value
FROM t1
         INNER JOIN t10 ON has(t10.arr, t1.id)
--where t1.id > 0
ORDER BY t1.id
    SETTINGS enable_analyzer = 0;

--- not working end


SELECT t1.id, t2.value
FROM t1
INNER JOIN t2 ON has(t2.arr, t1.id)
ORDER BY t1.id, t2.value;

SELECT trimLeft(explain) AS explain FROM (
    EXPLAIN actions=1
    SELECT t1.id, t2.value
    FROM t1
    INNER JOIN t2 ON has(t2.arr, t1.id) AND t1.name = t2.value
    SETTINGS enable_analyzer = 1)
WHERE explain LIKE 'Type%';

SELECT t1.id, t2.value
FROM t1
INNER JOIN t2 ON has(t2.arr, t1.id) AND t1.name = t2.value
ORDER BY t1.id, t2.value;

SELECT t1.id, t2.value
FROM t1
INNER JOIN t2 ON t1.name = t2.value AND has(t2.arr, t1.id)
ORDER BY t1.id, t2.value;

CREATE TABLE t3 (id UInt32, value String) ENGINE = Memory;
CREATE TABLE t4 (arr Array(UInt32), value String, category String) ENGINE = Memory;

INSERT INTO t3 VALUES (1, 'X'), (2, 'Y'), (3, 'Z');
INSERT INTO t4 VALUES ([1, 2], 'X', 'cat1'), ([2, 3], 'Y', 'cat2'), ([3], 'Z', 'cat1');

SELECT trimLeft(explain) AS explain FROM (
    EXPLAIN actions=1
    SELECT t3.id, t3.value, t4.category
    FROM t3
    INNER JOIN t4 ON has(t4.arr, t3.id) AND t3.value = t4.value
    SETTINGS enable_analyzer = 1)
WHERE explain LIKE 'Type%';

SELECT t3.id, t3.value, t4.category
FROM t3
INNER JOIN t4 ON has(t4.arr, t3.id) AND t3.value = t4.value
ORDER BY t3.id;

DROP TABLE IF EXISTS t5;
DROP TABLE IF EXISTS t6;

CREATE TABLE t5 (id UInt32, name String) ENGINE = Memory;
CREATE TABLE t6 (arr1 Array(UInt32), arr2 Array(String), value String) ENGINE = Memory;

INSERT INTO t5 VALUES (1, 'A'), (2, 'B'), (3, 'C');
INSERT INTO t6 VALUES ([1, 2], ['A', 'B'], 'Group1'), ([2, 3], ['B', 'C'], 'Group2'), ([1], ['C'], 'Group3');

SELECT trimLeft(explain) AS explain FROM (
    EXPLAIN actions=1
    SELECT t5.id, t5.name, t6.value
    FROM t5
    INNER JOIN t6 ON has(t6.arr1, t5.id) AND has(t6.arr2, t5.name)
    SETTINGS enable_analyzer = 1)
WHERE explain LIKE 'Type%';

SELECT t5.id, t5.name, t6.value
FROM t5
INNER JOIN t6 ON has(t6.arr1, t5.id) AND has(t6.arr2, t5.name)
ORDER BY t5.id, t6.value;


DROP TABLE IF EXISTS t7;
DROP TABLE IF EXISTS t8;

CREATE TABLE t7 (id UInt32, cat String, status String) ENGINE = Memory;
CREATE TABLE t8 (arr Array(UInt32), cat String, status String, name String) ENGINE = Memory;

INSERT INTO t7 VALUES (1, 'A', 'active'), (2, 'B', 'active'), (3, 'A', 'inactive');
INSERT INTO t8 VALUES ([1, 2], 'A', 'active', 'First'), ([2, 3], 'B', 'active', 'Second'), ([3], 'A', 'inactive', 'Third');

SELECT t7.id, t8.name
FROM t7
INNER JOIN t8 ON has(t8.arr, t7.id) AND t7.cat = t8.cat AND t7.status = t8.status
ORDER BY t7.id;


SELECT t3.id, t3.value, t4.category
FROM t3
INNER JOIN t4 ON has(t4.arr, t3.id) AND t3.value = t4.value
ORDER BY t3.id
SETTINGS enable_analyzer = 1;


DROP TABLE IF EXISTS t9;
CREATE TABLE t9 (arr Array(UInt32), value String) ENGINE = Memory;
INSERT INTO t9 VALUES ([], 'Empty');

SELECT t1.id, t9.value
FROM t1
INNER JOIN t9 ON has(t9.arr, t1.id) AND t1.name != ''
ORDER BY t1.id;






DROP TABLE IF EXISTS t1;
DROP TABLE IF EXISTS t2;
DROP TABLE IF EXISTS t3;
DROP TABLE IF EXISTS t4;
DROP TABLE IF EXISTS t5;
DROP TABLE IF EXISTS t6;
DROP TABLE IF EXISTS t7;
DROP TABLE IF EXISTS t8;
DROP TABLE IF EXISTS t9;
DROP TABLE IF EXISTS t10;
