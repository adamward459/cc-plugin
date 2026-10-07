set -e
mkdir -p src test
echo '{ "type": "module" }' > package.json
cat > src/shipping.js <<'JS'
export function shippingFee(orderTotal) {
  return 5;
}
JS
cat > test/shipping.test.js <<'JS'
import { test } from "node:test";
import assert from "node:assert/strict";
import { shippingFee } from "../src/shipping.js";

test("charges $5 shipping", () => {
  assert.equal(shippingFee(20), 5);
});

test("charges $5 shipping on large orders", () => {
  assert.equal(shippingFee(120), 5);
});
JS
