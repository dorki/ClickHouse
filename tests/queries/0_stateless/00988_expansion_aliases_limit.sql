SET max_expanded_ast_elements = 10000;
SELECT 1 AS a, a + a AS b, b + b AS c, c + c AS d, d + d AS e, e + e AS f, f + f AS g, g + g AS h, h + h AS i, i + i AS j, j + j AS k, k + k AS l, l + l AS m, m + m AS n, n + n AS o, o + o AS p, p + p AS q, q + q AS r, r + r AS s, s + s AS t, t + t AS u, u + u AS v, v + v AS w, w + w AS x, x + x AS y, y + y AS z; -- { serverError BAD_ARGUMENTS, 168 }
