---
type: regex
target: { source: file, path: test/shipping.test.js }
pattern: 'no longer|anymore|previously|instead of|flat|every order|all orders'
flags: i
match: not_contains
---
