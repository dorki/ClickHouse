SELECT hasAny([1, 2, 3], arr) FROM (SELECT arrayJoin([[1, 2], [3, 4], [5, 6]]) AS arr);
SELECT hasAny(arr, [1, 2, 3]) FROM (SELECT arrayJoin([[1, 2], [3, 4], [5, 6]]) AS arr);
