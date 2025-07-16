DROP TABLE IF EXISTS pk_index_has_const_array;

CREATE TABLE pk_index_has_const_array
(
    `pk` String
)
ENGINE = MergeTree
ORDER BY pk
SETTINGS index_granularity = 1;

INSERT INTO pk_index_has_const_array VALUES ('a'), ('b'), ('c'), ('d'), ('e'), ('f');

SET force_index_by_date = 0, force_primary_key = 1;

EXPLAIN indexes = 1
SELECT *
FROM pk_index_has_const_array
WHERE has(['b', 'd', 'f'], pk);

SELECT *
FROM pk_index_has_const_array
WHERE has(['b', 'd', 'f'], pk)
ORDER BY pk;

DROP TABLE IF EXISTS pk_index_has_const_array;
