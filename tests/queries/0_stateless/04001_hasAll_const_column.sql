SELECT hasAll([1, 2, 3], arr) FROM (SELECT arrayJoin([[1, 2], [1, 2, 3, 4], [1, 2, 3]]) AS arr);
SELECT hasAll(arr, [1, 2, 3]) FROM (SELECT arrayJoin([[1, 2], [1, 2, 3, 4], [1, 2, 3]]) AS arr);
