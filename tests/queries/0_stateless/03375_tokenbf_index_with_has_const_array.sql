DROP TABLE IF EXISTS tokenbf_has_const_array_test;

CREATE TABLE tokenbf_has_const_array_test
(
    id UInt32,
    array Array(String),
    INDEX idx_array_tokenbf_v1 array TYPE tokenbf_v1(512,3,0) GRANULARITY 1
) Engine=MergeTree() ORDER BY id SETTINGS index_granularity = 1;

INSERT INTO tokenbf_has_const_array_test VALUES (1, ['this is a test', 'example.com']), (2, ['another test', 'another example']);

SELECT * FROM tokenbf_has_const_array_test WHERE has(array, ['this is a test', 'another test']) ORDER BY id ASC SETTINGS force_data_skipping_indices='idx_array_tokenbf_v1';

DROP TABLE tokenbf_has_const_array_test;
