#!/bin/sh
# Deploy the shop's three Workers. Orders binds to inventory and payments,
# and Cloudflare rejects a Worker whose binding target doesn't exist yet, so
# the order below matters.
set -eu

for worker in inventory payments orders; do
  (cd "workers/$worker" && npx wrangler deploy)
done

# Each Worker's secrets, by name. Keep this list in step with the code.
put() { printf '%s' "$3" | npx wrangler secret put "$2" --name "$1"; }
put shop-orders AUTH_JWT_SECRET "$AUTH_JWT_SECRET"
put shop-payments PAYMENTS_WEBHOOK_SECRET "$PAYMENTS_WEBHOOK_SECRET"
put shop-payments PAYMENTS_API_KEY "$PAYMENTS_API_KEY"
