SET parallel_replicas_local_plan=1;

DROP TABLE IF EXISTS t1;
DROP TABLE IF EXISTS t10;

CREATE TABLE t1 (id UInt32, name String) ENGINE = Memory;
CREATE TABLE t10 (arr Array(Nullable(UInt32)), value String) ENGINE = Memory;

INSERT INTO t1 VALUES (1, 'Alice'), (2, 'Bob'), (3, 'Charlie');
INSERT INTO t10 VALUES ([1, NULL, 2], 'WithNull');

select 'new grace_hash';
--explain actions =1 
SELECT t1.id, t10.value
FROM t10
INNER JOIN t1 ON has(t10.arr, t1.id)
--where t1.id > 0
ORDER BY t1.id
SETTINGS enable_analyzer = 1, join_algorithm='grace_hash';

select 'old grace_hash';
--explain actions =1 
SELECT t1.id, t10.value
FROM t10
INNER JOIN t1 ON has(t10.arr, t1.id)
--where t1.id > 0
ORDER BY t1.id
SETTINGS enable_analyzer = 0, join_algorithm='grace_hash';



select 'new hash';
--explain actions =1 
SELECT t1.id, t10.value
FROM t10
INNER JOIN t1 ON has(t10.arr, t1.id)
--where t1.id > 0
ORDER BY t1.id
SETTINGS enable_analyzer = 1, join_algorithm='hash';

select 'old hash';
--explain actions =1 
SELECT t1.id, t10.value
FROM t10
INNER JOIN t1 ON has(t10.arr, t1.id)
--where t1.id > 0
ORDER BY t1.id
SETTINGS enable_analyzer = 0, join_algorithm='hash';

select 'new parallel_hash';
--explain actions =1 
SELECT t1.id, t10.value
FROM t10
INNER JOIN t1 ON has(t10.arr, t1.id)
--where t1.id > 0
ORDER BY t1.id
SETTINGS enable_analyzer = 1, join_algorithm='parallel_hash';

select 'old parallel_hash';
--explain actions =1 
SELECT t1.id, t10.value
FROM t10
INNER JOIN t1 ON has(t10.arr, t1.id)
--where t1.id > 0
ORDER BY t1.id
SETTINGS enable_analyzer = 0, join_algorithm='parallel_hash';
--- not working end
