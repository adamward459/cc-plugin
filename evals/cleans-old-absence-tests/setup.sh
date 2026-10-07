set -e
mkdir -p src test
echo '{ "type": "module" }' > package.json
cat > src/points.js <<'JS'
export function loyaltyPoints(orderTotal, customer) {
  return Math.floor(orderTotal) * 2;
}
JS
cat > test/points.test.js <<'JS'
import { test } from "node:test";
import assert from "node:assert/strict";
import { loyaltyPoints } from "../src/points.js";

test("gives 2 points per dollar", () => {
  assert.equal(loyaltyPoints(30, { member: true }), 60);
});

test("gives 2 points per dollar to guests", () => {
  assert.equal(loyaltyPoints(30, { member: false }), 60);
});

test("no longer gives 1 point per dollar", () => {
  assert.notEqual(loyaltyPoints(30, { member: true }), 30);
});
JS
