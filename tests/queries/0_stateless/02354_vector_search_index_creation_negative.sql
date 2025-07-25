-- Tags: no-fasttest, no-ordinary-database

-- Tests that various conditions are checked during creation of vector search indexes.

SET enable_vector_similarity_index = 1;

DROP TABLE IF EXISTS tab;

SELECT 'Three or six index arguments';
CREATE TABLE tab(id Int32, vec Array(Float32), INDEX idx vec TYPE vector_similarity) ENGINE = MergeTree ORDER BY id; -- { serverError INCORRECT_QUERY }
CREATE TABLE tab(id Int32, vec Array(Float32), INDEX idx vec TYPE vector_similarity()) ENGINE = MergeTree ORDER BY id; -- { serverError INCORRECT_QUERY }
CREATE TABLE tab(id Int32, vec Array(Float32), INDEX idx vec TYPE vector_similarity('cant have', 'two args')) ENGINE = MergeTree ORDER BY id; -- { serverError INCORRECT_QUERY }
CREATE TABLE tab(id Int32, vec Array(Float32), INDEX idx vec TYPE vector_similarity('cant', 'have', 'four', 'args')) ENGINE = MergeTree ORDER BY id; -- { serverError INCORRECT_QUERY }
CREATE TABLE tab(id Int32, vec Array(Float32), INDEX idx vec TYPE vector_similarity('cant', 'have', 'five', 'args', '!', '!')) ENGINE = MergeTree ORDER BY id; -- { serverError INCORRECT_QUERY }
CREATE TABLE tab(id Int32, vec Array(Float32), INDEX idx vec TYPE vector_similarity('cant', 'have', 'seven', 'args', '!', '!', '!')) ENGINE = MergeTree ORDER BY id; -- { serverError INCORRECT_QUERY }

SELECT '1st argument (method) must be String and hnsw';
CREATE TABLE tab(id Int32, vec Array(Float32), INDEX idx vec TYPE vector_similarity(3, 'L2Distance', 1)) ENGINE = MergeTree ORDER BY id; -- { serverError INCORRECT_QUERY }
CREATE TABLE tab(id Int32, vec Array(Float32), INDEX idx vec TYPE vector_similarity('not_hnsw', 'L2Distance', 1)) ENGINE = MergeTree ORDER BY id; -- { serverError INCORRECT_DATA }

SELECT '2nd argument (distance function) must be String and L2Distance or cosineDistance';
CREATE TABLE tab(id Int32, vec Array(Float32), INDEX idx vec TYPE vector_similarity('hnsw', 3, 1)) ENGINE = MergeTree ORDER BY id; -- { serverError INCORRECT_QUERY }
CREATE TABLE tab(id Int32, vec Array(Float32), INDEX idx vec TYPE vector_similarity('hnsw', 'invalid_distance', 1)) ENGINE = MergeTree ORDER BY id; -- { serverError INCORRECT_DATA }

SELECT '3nd argument (dimensions) must be UInt64 and > 0';
CREATE TABLE tab(id Int32, vec Array(Float32), INDEX idx vec TYPE vector_similarity('hnsw', 'L2Distance', 'invalid')) ENGINE = MergeTree ORDER BY id; -- { serverError INCORRECT_QUERY }
CREATE TABLE tab(id Int32, vec Array(Float32), INDEX idx vec TYPE vector_similarity('hnsw', 'L2Distance', 0)) ENGINE = MergeTree ORDER BY id; -- { serverError INCORRECT_DATA }

SELECT '4nd argument (quantization), if given, must be String and f32, f16, ...';
CREATE TABLE tab(id Int32, vec Array(Float32), INDEX idx vec TYPE vector_similarity('hnsw', 'L2Distance', 1, 1, 1, 1)) ENGINE = MergeTree ORDER BY id; -- { serverError INCORRECT_QUERY }
CREATE TABLE tab(id Int32, vec Array(Float32), INDEX idx vec TYPE vector_similarity('hnsw', 'L2Distance', 1, 'invalid', 2, 1)) ENGINE = MergeTree ORDER BY id; -- { serverError INCORRECT_DATA }

SELECT '5nd argument (M), if given, must be UInt64 and > 1';
CREATE TABLE tab(id Int32, vec Array(Float32), INDEX idx vec TYPE vector_similarity('hnsw', 'L2Distance', 1, 'f32', 'invalid', 1, 1)) ENGINE = MergeTree ORDER BY id; -- { serverError INCORRECT_QUERY }
CREATE TABLE tab(id Int32, vec Array(Float32), INDEX idx vec TYPE vector_similarity('hnsw', 'L2Distance', 1, 'f32', 1, 1)) ENGINE = MergeTree ORDER BY id; -- { serverError INCORRECT_DATA }

SELECT 'Must be created on single column';
CREATE TABLE tab(id Int32, vec Array(Float32), INDEX idx (vec, id) TYPE vector_similarity('hnsw', 'L2Distance', 1)) ENGINE = MergeTree ORDER BY id; -- { serverError INCORRECT_NUMBER_OF_COLUMNS }

SELECT 'Must be created on Array(Float32|Float64|BFloat16) columns';
SET allow_suspicious_low_cardinality_types = 1;
CREATE TABLE tab(id Int32, vec UInt64, INDEX idx vec TYPE vector_similarity('hnsw', 'L2Distance', 1)) ENGINE = MergeTree ORDER BY id; -- { serverError ILLEGAL_COLUMN }
CREATE TABLE tab(id Int32, vec Float32, INDEX idx vec TYPE vector_similarity('hnsw', 'L2Distance', 1)) ENGINE = MergeTree ORDER BY id; -- { serverError ILLEGAL_COLUMN }
CREATE TABLE tab(id Int32, vec LowCardinality(Float32), INDEX idx vec TYPE vector_similarity('hnsw', 'L2Distance', 1)) ENGINE = MergeTree ORDER BY id; -- { serverError ILLEGAL_COLUMN }
CREATE TABLE tab(id Int32, vec Nullable(Float32), INDEX idx vec TYPE vector_similarity('hnsw', 'L2Distance', 1)) ENGINE = MergeTree ORDER BY id; -- { serverError ILLEGAL_COLUMN }
CREATE TABLE tab(id Int32, vec Array(UInt64), INDEX idx vec TYPE vector_similarity('hnsw', 'L2Distance', 1)) ENGINE = MergeTree ORDER BY id; -- { serverError ILLEGAL_COLUMN }
CREATE TABLE tab(id Int32, vec Array(Nullable(Float32)), INDEX idx vec TYPE vector_similarity('hnsw', 'L2Distance', 1)) ENGINE = MergeTree ORDER BY id; -- { serverError ILLEGAL_COLUMN }
CREATE TABLE tab(id Int32, vec Array(LowCardinality(Float32)), INDEX idx vec TYPE vector_similarity('hnsw', 'L2Distance', 1)) ENGINE = MergeTree ORDER BY id; -- { serverError ILLEGAL_COLUMN }
