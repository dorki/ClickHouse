SET parallel_replicas_local_plan=1;

DROP TABLE IF EXISTS t1;
DROP TABLE IF EXISTS t10;

CREATE TABLE t1 (id UInt32, name String) ENGINE = Memory;
CREATE TABLE t10 (arr Array(Nullable(UInt32)), value String) ENGINE = Memory;

INSERT INTO t1 VALUES (1, 'Alice'), (2, 'Bob'), (3, 'Charlie');
INSERT INTO t10 VALUES ([1, NULL, 2], 'WithNull');

select 'old';
SELECT t1.id, t10.value
FROM t1
INNER JOIN t10 ON has(t10.arr, t1.id)
--where t1.id > 0
ORDER BY t1.id
SETTINGS enable_analyzer = 0, join_algorithm='hash';

--- not working end
