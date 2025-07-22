DROP TABLE IF EXISTS bloom_filter_has_const_array_test;

CREATE TABLE bloom_filter_has_const_array_test
(
    id UInt32,
    s String,
    arr Array(String),
    INDEX bf_s s TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX bf_arr arr TYPE bloom_filter(0.01) GRANULARITY 1
) Engine=MergeTree() ORDER BY id SETTINGS index_granularity = 1;

INSERT INTO bloom_filter_has_const_array_test VALUES (1, 'this is a test', ['this is a test', 'example.com']), (2, 'another test', ['another test', 'another example']);

SELECT * FROM bloom_filter_has_const_array_test WHERE has(arr, ['this is a test', 'another test']) ORDER BY id ASC SETTINGS force_data_skipping_indices='bf_arr';
SELECT '--';
SELECT * FROM bloom_filter_has_const_array_test WHERE has(s, 'this is a test') ORDER BY id ASC SETTINGS force_data_skipping_indices='bf_s';
SELECT '--';
SELECT * FROM bloom_filter_has_const_array_test WHERE hasAny(['this is a test', 'another test'], arr) ORDER BY id ASC SETTINGS force_data_skipping_indices='bf_arr';
SELECT '--';
SELECT * FROM bloom_filter_has_const_array_test WHERE hasAll(['this is a test'], arr) ORDER BY id ASC SETTINGS force_data_skipping_indices='bf_arr';


DROP TABLE bloom_filter_has_const_array_test;

DROP TABLE IF EXISTS tokenbf_has_const_array_test;

CREATE TABLE tokenbf_has_const_array_test
(
    id UInt32,
    s String,
    arr Array(String),
    INDEX idx_s s TYPE tokenbf_v1(512,3,0) GRANULARITY 1,
    INDEX idx_arr arr TYPE tokenbf_v1(512,3,0) GRANULARITY 1
) Engine=MergeTree() ORDER BY id SETTINGS index_granularity = 1;

INSERT INTO tokenbf_has_const_array_test VALUES (1, 'this is a test', ['this is a test', 'example.com']), (2, 'another test', ['another test', 'another example']);

SELECT * FROM tokenbf_has_const_array_test WHERE has(arr, ['this is a test', 'another test']) ORDER BY id ASC SETTINGS force_data_skipping_indices='idx_arr';
SELECT '--';
SELECT * FROM tokenbf_has_const_array_test WHERE has(s, 'this is a test') ORDER BY id ASC SETTINGS force_data_skipping_indices='idx_s';
SELECT '--';
SELECT * FROM tokenbf_has_const_array_test WHERE hasAny(['this is a test', 'another test'], arr) ORDER BY id ASC SETTINGS force_data_skipping_indices='idx_arr';
SELECT '--';
SELECT * FROM tokenbf_has_const_array_test WHERE hasAll(['this is a test'], arr) ORDER BY id ASC SETTINGS force_data_skipping_indices='idx_arr';


DROP TABLE tokenbf_has_const_array_test;

DROP TABLE IF EXISTS ngrambf_has_const_array_test;

CREATE TABLE ngrambf_has_const_array_test
(
    id UInt32,
    s String,
    arr Array(String),
    INDEX idx_s s TYPE ngrambf_v1(3, 512, 3, 0) GRANULARITY 1,
    INDEX idx_arr arr TYPE ngrambf_v1(3, 512, 3, 0) GRANULARITY 1
) Engine=MergeTree() ORDER BY id SETTINGS index_granularity = 1;

INSERT INTO ngrambf_has_const_array_test VALUES (1, 'this is a test', ['this is a test', 'example.com']), (2, 'another test', ['another test', 'another example']);

SELECT * FROM ngrambf_has_const_array_test WHERE has(arr, ['this is a test', 'another test']) ORDER BY id ASC SETTINGS force_data_skipping_indices='idx_arr';
SELECT '--';
SELECT * FROM ngrambf_has_const_array_test WHERE has(s, 'this is a test') ORDER BY id ASC SETTINGS force_data_skipping_indices='idx_s';
SELECT '--';
SELECT * FROM ngrambf_has_const_array_test WHERE hasAny(['this is a test', 'another test'], arr) ORDER BY id ASC SETTINGS force_data_skipping_indices='idx_arr';
SELECT '--';
SELECT * FROM ngrambf_has_const_array_test WHERE hasAll(['this is a test'], arr) ORDER BY id ASC SETTINGS force_data_skipping_indices='idx_arr';


DROP TABLE ngrambf_has_const_array_test;
