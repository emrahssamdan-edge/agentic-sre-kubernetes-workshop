#!/usr/bin/env bash
#
# Generate traffic against EasyTrade services.
# This script sends requests to key API endpoints in a loop,
# producing the kind of traffic that triggers visible errors
# when failure patterns are enabled.
#
# Usage:
#   ./scripts/generate-traffic.sh [BASE_URL]
#
# Default BASE_URL: http://localhost:9090

set -euo pipefail

BASE_URL="${1:-http://localhost:9090}"
INTERVAL="${INTERVAL:-2}"  # seconds between request batches

echo "Generating traffic against $BASE_URL"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

request() {
  local method="$1"
  local path="$2"
  local data="${3:-}"
  local label="${4:-$path}"

  local args=(-s -m 10 -o /dev/null -w "%{http_code}" -X "$method")
  if [ -n "$data" ]; then
    args+=(-H "Content-Type: application/json" -d "$data")
  fi

  local code
  code=$(curl "${args[@]}" "${BASE_URL}${path}" 2>/dev/null || echo "000")

  if [ "$code" -ge 200 ] && [ "$code" -lt 300 ] 2>/dev/null; then
    printf "${GREEN}[%s]${NC} %s %s\n" "$code" "$method" "$label"
  elif [ "$code" -ge 400 ] 2>/dev/null; then
    printf "${RED}[%s]${NC} %s %s\n" "$code" "$method" "$label"
  else
    printf "${YELLOW}[%s]${NC} %s %s\n" "$code" "$method" "$label"
  fi
}

echo "Press Ctrl+C to stop"
echo "---"

iteration=0
while true; do
  iteration=$((iteration + 1))
  echo "--- batch $iteration ---"

  # Account and login endpoints (affected by DB outage)
  request GET  "/accountservice/api/accounts/presets"         "" "accounts/presets"
  request POST "/loginservice/api/Login"                      '{"username":"demouser","password":"demopass"}' "login"

  # Trading endpoints (affected by DB outage)
  request POST "/broker-service/api/trade/BuyAssets"          '{"accountId":1,"instrumentId":1,"amount":100,"price":1.5}' "buy assets"
  request POST "/broker-service/api/trade/SellAssets"         '{"accountId":1,"instrumentId":1,"amount":50,"price":1.5}' "sell assets"

  # Engine - triggers long-running transactions
  request GET  "/engine/api/trade/scheduler/start"            "" "engine scheduler"

  # Credit card endpoints (affected by credit card meltdown)
  request GET  "/credit-card-order-service/v1/orders/1/status" "" "credit card status"
  request POST "/credit-card-order-service/v1/orders"         '{"cardLevel":"gold","cardholderName":"Demo User","deliveryAddress":"123 Main St"}' "credit card order"

  # Third party service (affected by factory crisis)
  request GET  "/third-party-service/v1/manufacturer/status"  "" "manufacturer status"

  # Offer service (checks feature flags)
  request GET  "/offerservice/api/offers/1"                   "" "get offer"

  # Manager service
  request GET  "/manager/api/Products/GetProducts"            "" "get products"
  request GET  "/manager/api/Packages/GetPackages"            "" "get packages"

  # Pricing service
  request GET  "/pricing-service/api/price/instrument/1"      "" "instrument price"

  # Feature flag service (always useful to see current state)
  request GET  "/feature-flag-service/v1/flags"               "" "feature flags"

  sleep "$INTERVAL"
done
