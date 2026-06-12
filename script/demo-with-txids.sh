#!/usr/bin/env bash
set -euo pipefail

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

NETWORK="${VOL_E2E_NETWORK:-base-sepolia}"
E2E_DOC="${E2E_DOC:-docs/e2e.md}"
REQUIRE_DEPLOYED="${REQUIRE_DEPLOYED:-0}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

phase() {
  echo
  echo "================================================================"
  echo "$1"
  echo "================================================================"
}

select_network() {
  case "$NETWORK" in
    sepolia)
      RPC_URL="${SEPOLIA_RPC_URL:?SEPOLIA_RPC_URL required}"
      CHAIN_ID="11155111"
      POOL_MANAGER="$SEPOLIA_POOL_MANAGER"
      POOL_SWAP_TEST="$SEPOLIA_POOL_SWAP_TEST"
      POOL_MODIFY_LIQUIDITY_TEST="$SEPOLIA_POOL_MODIFY_LIQUIDITY_TEST"
      EXPLORER="https://sepolia.etherscan.io"
      ;;
    base|base-sepolia|base_sepolia)
      NETWORK="base-sepolia"
      RPC_URL="${BASE_SEPOLIA_RPC_URL:?BASE_SEPOLIA_RPC_URL required}"
      CHAIN_ID="84532"
      POOL_MANAGER="$BASE_SEPOLIA_POOL_MANAGER"
      POOL_SWAP_TEST="$BASE_SEPOLIA_POOL_SWAP_TEST"
      POOL_MODIFY_LIQUIDITY_TEST="$BASE_SEPOLIA_POOL_MODIFY_LIQUIDITY_TEST"
      EXPLORER="https://sepolia.basescan.org"
      ;;
    unichain|unichain-sepolia|unichain_sepolia)
      NETWORK="unichain-sepolia"
      RPC_URL="${UNICHAIN_SEPOLIA_RPC_URL:?UNICHAIN_SEPOLIA_RPC_URL required}"
      CHAIN_ID="1301"
      POOL_MANAGER="$UNICHAIN_SEPOLIA_POOL_MANAGER"
      POOL_SWAP_TEST="$UNICHAIN_SEPOLIA_POOL_SWAP_TEST"
      POOL_MODIFY_LIQUIDITY_TEST="$UNICHAIN_SEPOLIA_POOL_MODIFY_LIQUIDITY_TEST"
      EXPLORER="https://sepolia.uniscan.xyz"
      ;;
    *)
      echo "Unsupported VOL_E2E_NETWORK=$NETWORK" >&2
      exit 1
      ;;
  esac
}

tx_url() {
  echo "$EXPLORER/tx/$1"
}

contract_url() {
  echo "$EXPLORER/address/$1"
}

lasna_tx_url() {
  echo "https://lasna.reactscan.net/tx/$1"
}

rnk_tail_start() {
  local last_hex="${1#0x}"
  local last_dec=$((16#$last_hex))
  local window_dec="${RVM_TX_WINDOW:-96}"
  local start_dec=0
  if (( last_dec > window_dec )); then
    start_dec=$((last_dec - window_dec))
  fi
  printf "0x%x" "$start_dec"
}

lowercase() {
  printf "%s" "$1" | tr '[:upper:]' '[:lower:]'
}

append_doc() {
  mkdir -p "$(dirname "$E2E_DOC")"
  {
    echo
    echo "## $(date -u +"%Y-%m-%dT%H:%M:%SZ") - $NETWORK"
    echo
    echo "- PoolManager: $POOL_MANAGER"
    echo "- Hook: ${VOLATILITY_FEE_HOOK:-not set}"
    echo "- RSC: ${VOLATILITY_FEE_RSC:-not set}"
    echo "- RSC deploy tx: ${RSC_DEPLOY_TX:-not set}"
    echo "- RSC subscription tx: ${RSC_SUBSCRIPTION_TX:-not set}"
    echo "- PoolId: ${POOL_ID:-not set}"
    echo "- Callback proxy: ${CALLBACK_PROXY:-not set}"
    echo "- RVM sender: ${RVM_SENDER:-not set}"
    echo "- Demo mode: ${DIRECT_SIMULATE:-0}"
    echo "- Live swaps mode: ${RUN_LIVE_SWAPS:-0}"
    if [[ -n "${LIVE_SWAP_TXS:-}" ]]; then
      echo "- Live swap txs: $LIVE_SWAP_TXS"
    fi
    if [[ -n "${TXID:-}" ]]; then
      echo "- Latest direct simulation tx: $(tx_url "$TXID")"
    fi
    if [[ -n "${RSC_STATUS:-}" ]]; then
      echo "- RSC status: $RSC_STATUS"
    fi
    if [[ -n "${SUBSCRIPTION_STATUS:-}" ]]; then
      echo "- RSC subscriptionConfigured: $SUBSCRIPTION_STATUS"
    fi
    if [[ -n "${OBSERVED_SWAPS_STATUS:-}" ]]; then
      echo "- RSC observedSwaps: $OBSERVED_SWAPS_STATUS"
    fi
    if [[ -n "${RSC_TX_STATUS:-}" ]]; then
      echo "- RSC tx status: $RSC_TX_STATUS"
    fi
    if [[ -n "${RSC_SUBSCRIPTION_TX_STATUS:-}" ]]; then
      echo "- RSC subscription tx status: $RSC_SUBSCRIPTION_TX_STATUS"
    fi
    if [[ -n "${RVM_TX_STATUS:-}" ]]; then
      echo "- RNK RVM tx status: $RVM_TX_STATUS"
    fi
    if [[ -n "${RNK_FILTER_STATUS:-}" ]]; then
      echo "- RNK filter status: $RNK_FILTER_STATUS"
    fi
    if [[ -n "${RVM_TX_LINES:-}" ]]; then
      echo "- RNK RVM txs:"
      printf '%s\n' "$RVM_TX_LINES"
    fi
    if [[ -n "${FEE_UPDATED_STATUS:-}" ]]; then
      echo "- Destination FeeUpdated status: $FEE_UPDATED_STATUS"
    fi
    if [[ -n "${CALLBACK_DEBT_STATUS:-}" ]]; then
      echo "- Callback debt status: $CALLBACK_DEBT_STATUS"
    fi
  } >>"$E2E_DOC"
}

require_cmd forge
require_cmd cast
require_cmd jq
select_network

load_network_values() {
  case "$NETWORK" in
    base-sepolia)
      VOLATILITY_FEE_HOOK="${VOLATILITY_FEE_HOOK:-${BASE_SEPOLIA_VOLATILITY_FEE_HOOK:-}}"
      VOLATILITY_FEE_RSC="${VOLATILITY_FEE_RSC:-${BASE_SEPOLIA_VOLATILITY_FEE_RSC:-${BASE_SEPOLIA_VOLATILITY_FEE_RSC_PENDING:-}}}"
      RSC_DEPLOY_TX="${RSC_DEPLOY_TX:-${BASE_SEPOLIA_VOLATILITY_FEE_RSC_TX:-${BASE_SEPOLIA_VOLATILITY_FEE_RSC_PENDING_TX:-}}}"
      RSC_SUBSCRIPTION_TX="${RSC_SUBSCRIPTION_TX:-${BASE_SEPOLIA_VOLATILITY_FEE_RSC_SUBSCRIPTION_TX:-}}"
      POOL_ID="${POOL_ID:-${BASE_SEPOLIA_VOLATILITY_FEE_POOL_ID:-}}"
      DEMO_TOKEN0="${DEMO_TOKEN0:-${BASE_SEPOLIA_VOLATILITY_FEE_DEMO_TOKEN0:-}}"
      DEMO_TOKEN1="${DEMO_TOKEN1:-${BASE_SEPOLIA_VOLATILITY_FEE_DEMO_TOKEN1:-}}"
      CALLBACK_PROXY="${CALLBACK_PROXY:-${BASE_SEPOLIA_CALLBACK_PROXY:-${REACTIVE_SYSTEM_CONTRACT:-}}}"
      RVM_SENDER="${RVM_SENDER:-${BASE_SEPOLIA_VOLATILITY_FEE_RVM_SENDER:-${REACTIVE_SENDER:-}}}"
      ;;
    sepolia)
      VOLATILITY_FEE_HOOK="${VOLATILITY_FEE_HOOK:-${SEPOLIA_VOLATILITY_FEE_HOOK:-}}"
      VOLATILITY_FEE_RSC="${VOLATILITY_FEE_RSC:-${SEPOLIA_VOLATILITY_FEE_RSC:-}}"
      RSC_DEPLOY_TX="${RSC_DEPLOY_TX:-${SEPOLIA_VOLATILITY_FEE_RSC_TX:-${SEPOLIA_VOLATILITY_FEE_RSC_PENDING_TX:-}}}"
      RSC_SUBSCRIPTION_TX="${RSC_SUBSCRIPTION_TX:-${SEPOLIA_VOLATILITY_FEE_RSC_SUBSCRIPTION_TX:-}}"
      POOL_ID="${POOL_ID:-${SEPOLIA_VOLATILITY_FEE_POOL_ID:-}}"
      DEMO_TOKEN0="${DEMO_TOKEN0:-${SEPOLIA_VOLATILITY_FEE_DEMO_TOKEN0:-}}"
      DEMO_TOKEN1="${DEMO_TOKEN1:-${SEPOLIA_VOLATILITY_FEE_DEMO_TOKEN1:-}}"
      CALLBACK_PROXY="${CALLBACK_PROXY:-${SEPOLIA_CALLBACK_PROXY:-${REACTIVE_SYSTEM_CONTRACT:-}}}"
      RVM_SENDER="${RVM_SENDER:-${SEPOLIA_VOLATILITY_FEE_RVM_SENDER:-${REACTIVE_SENDER:-}}}"
      ;;
    unichain-sepolia)
      VOLATILITY_FEE_HOOK="${VOLATILITY_FEE_HOOK:-${UNICHAIN_SEPOLIA_VOLATILITY_FEE_HOOK:-}}"
      VOLATILITY_FEE_RSC="${VOLATILITY_FEE_RSC:-${UNICHAIN_SEPOLIA_VOLATILITY_FEE_RSC:-}}"
      RSC_DEPLOY_TX="${RSC_DEPLOY_TX:-${UNICHAIN_SEPOLIA_VOLATILITY_FEE_RSC_TX:-${UNICHAIN_SEPOLIA_VOLATILITY_FEE_RSC_PENDING_TX:-}}}"
      RSC_SUBSCRIPTION_TX="${RSC_SUBSCRIPTION_TX:-${UNICHAIN_SEPOLIA_VOLATILITY_FEE_RSC_SUBSCRIPTION_TX:-}}"
      POOL_ID="${POOL_ID:-${UNICHAIN_SEPOLIA_VOLATILITY_FEE_POOL_ID:-}}"
      DEMO_TOKEN0="${DEMO_TOKEN0:-${UNICHAIN_SEPOLIA_VOLATILITY_FEE_DEMO_TOKEN0:-}}"
      DEMO_TOKEN1="${DEMO_TOKEN1:-${UNICHAIN_SEPOLIA_VOLATILITY_FEE_DEMO_TOKEN1:-}}"
      CALLBACK_PROXY="${CALLBACK_PROXY:-${UNICHAIN_SEPOLIA_CALLBACK_PROXY:-${REACTIVE_SYSTEM_CONTRACT:-}}}"
      RVM_SENDER="${RVM_SENDER:-${UNICHAIN_SEPOLIA_VOLATILITY_FEE_RVM_SENDER:-${REACTIVE_SENDER:-}}}"
      ;;
  esac

  if [[ -z "${RVM_SENDER:-}" && -n "${PRIVATE_KEY:-}" ]]; then
    RVM_SENDER="$(cast wallet address --private-key "$PRIVATE_KEY")"
  fi
}

load_network_values
LASNA_RPC="${LASNA_RPC_URL:-https://lasna-rpc.rnk.dev/}"

phase "VolatilityFee Hook E2E"
cat <<EOF
Network: $NETWORK
Destination chain id: $CHAIN_ID
PoolManager: $POOL_MANAGER
Reactive Lasna RPC: ${LASNA_RPC_URL:-https://lasna-rpc.rnk.dev/}

This runner prints the proof classes judges care about:
  1. destination hook deployment
  2. Lasna RSC deployment/subscription
  3. origin SwapPriceUpdate events
  4. Lasna RVM event processing
  5. destination FeeUpdated callback settlement

EOF

phase "Build and test proof"
forge build
forge test

phase "Deployment readback"
if [[ -z "${VOLATILITY_FEE_HOOK:-}" || -z "${VOLATILITY_FEE_RSC:-}" ]]; then
  echo "VOLATILITY_FEE_HOOK or VOLATILITY_FEE_RSC is not set yet."
  echo "Run deployment first, then re-run this script:"
  echo "  POOL_MANAGER=$POOL_MANAGER CALLBACK_PROXY=<reactive callback proxy> REACTIVE_SENDER=<rsc callback sender> forge script script/Deploy.s.sol:DeployVolatilityFeeHook --rpc-url $RPC_URL --broadcast"
  echo "  DESTINATION_CHAIN_ID=$CHAIN_ID VOLATILITY_FEE_HOOK=<hook> forge script script/DeployRSC.s.sol:DeployVolatilityFeeRSC --rpc-url ${LASNA_RPC_URL:-https://lasna-rpc.rnk.dev/} --broadcast"
  append_doc
  if [[ "$REQUIRE_DEPLOYED" == "1" ]]; then exit 1; fi
  exit 0
fi

echo "Hook: $VOLATILITY_FEE_HOOK"
echo "Hook URL: $(contract_url "$VOLATILITY_FEE_HOOK")"
echo "RSC: $VOLATILITY_FEE_RSC"
echo "Lasna RSC URL: https://lasna.reactscan.net/address/$VOLATILITY_FEE_RSC"
if [[ -n "${RSC_DEPLOY_TX:-}" ]]; then
  echo "Lasna RSC deploy tx: $RSC_DEPLOY_TX"
  echo "Lasna RSC deploy tx URL: $(lasna_tx_url "$RSC_DEPLOY_TX")"
fi
if [[ -n "${RSC_SUBSCRIPTION_TX:-}" ]]; then
  echo "Lasna subscription tx: $RSC_SUBSCRIPTION_TX"
  echo "Lasna subscription tx URL: $(lasna_tx_url "$RSC_SUBSCRIPTION_TX")"
fi
echo "Callback proxy: ${CALLBACK_PROXY:-not set}"
echo "RVM sender: ${RVM_SENDER:-not set}"

phase "Lasna subscription receipt"
if [[ -n "${RSC_SUBSCRIPTION_TX:-}" ]]; then
  SUBSCRIPTION_RECEIPT_JSON="$(cast receipt "$RSC_SUBSCRIPTION_TX" --rpc-url "$LASNA_RPC" --json 2>/dev/null || true)"
  if jq -e . >/dev/null 2>&1 <<<"$SUBSCRIPTION_RECEIPT_JSON"; then
    SUB_BLOCK="$(jq -r '.blockNumber // "unknown"' <<<"$SUBSCRIPTION_RECEIPT_JSON")"
    SUB_STATUS="$(jq -r '.status // "unknown"' <<<"$SUBSCRIPTION_RECEIPT_JSON")"
    SUB_LOG_COUNT="$(jq -r '.logs | length' <<<"$SUBSCRIPTION_RECEIPT_JSON")"
    SUB_SYSTEM_TOPIC="$(jq -r '.logs[0].topics[0] // "missing"' <<<"$SUBSCRIPTION_RECEIPT_JSON")"
    SUB_RSC_TOPIC="$(jq -r '.logs[1].topics[0] // "missing"' <<<"$SUBSCRIPTION_RECEIPT_JSON")"
    RSC_SUBSCRIPTION_TX_STATUS="status=$SUB_STATUS block=$SUB_BLOCK logs=$SUB_LOG_COUNT systemTopic=$SUB_SYSTEM_TOPIC rscTopic=$SUB_RSC_TOPIC"
    echo "Subscription tx status: $RSC_SUBSCRIPTION_TX_STATUS"
  else
    RSC_SUBSCRIPTION_TX_STATUS="$(cast receipt "$RSC_SUBSCRIPTION_TX" --rpc-url "$LASNA_RPC" 2>&1 | awk '/blockNumber|status|transactionHash/ {print}' | paste -sd '; ' - || true)"
    echo "Subscription tx status: $RSC_SUBSCRIPTION_TX_STATUS"
  fi
else
  RSC_SUBSCRIPTION_TX_STATUS="not set"
  echo "No Lasna subscription tx configured for $NETWORK."
fi

phase "Hook state"
if [[ -z "${POOL_ID:-}" ]]; then
  echo "No real PoolId wired for $NETWORK."
  echo "Run:"
  echo "  POOL_MANAGER=$POOL_MANAGER VOLATILITY_FEE_HOOK=$VOLATILITY_FEE_HOOK POOL_MODIFY_LIQUIDITY_TEST=$POOL_MODIFY_LIQUIDITY_TEST POOL_SWAP_TEST=$POOL_SWAP_TEST forge script script/DeployDemoPool.s.sol:DeployVolatilityFeeDemoPool --rpc-url $RPC_URL --broadcast"
  append_doc
  if [[ "$REQUIRE_DEPLOYED" == "1" ]]; then exit 1; fi
  exit 0
fi
STATE="$(cast call "$VOLATILITY_FEE_HOOK" "getVolatilityState(bytes32)((uint24,uint160,uint256,uint256))" "$POOL_ID" --rpc-url "$RPC_URL" || true)"
echo "PoolId: $POOL_ID"
echo "Volatility state: $STATE"
echo "Pool events: $(contract_url "$VOLATILITY_FEE_HOOK")#events"

HOOK_CALLBACK_PROXY="$(cast call "$VOLATILITY_FEE_HOOK" "callbackProxy()(address)" --rpc-url "$RPC_URL")"
HOOK_REACTIVE_SENDER="$(cast call "$VOLATILITY_FEE_HOOK" "reactiveSender()(address)" --rpc-url "$RPC_URL")"
echo "Hook callbackProxy(): $HOOK_CALLBACK_PROXY"
echo "Hook reactiveSender(): $HOOK_REACTIVE_SENDER"

if [[ -n "${CALLBACK_PROXY:-}" && "$(lowercase "$HOOK_CALLBACK_PROXY")" != "$(lowercase "$CALLBACK_PROXY")" ]]; then
  echo "Callback proxy mismatch. Expected $CALLBACK_PROXY but hook has $HOOK_CALLBACK_PROXY." >&2
  append_doc
  exit 1
fi

if [[ -n "${RVM_SENDER:-}" && "$(lowercase "$HOOK_REACTIVE_SENDER")" != "$(lowercase "$RVM_SENDER")" ]]; then
  echo "RVM sender mismatch. Expected $RVM_SENDER but hook has $HOOK_REACTIVE_SENDER." >&2
  append_doc
  exit 1
fi

phase "Direct callback simulation"
if [[ "${DIRECT_SIMULATE:-0}" == "1" ]]; then
  NEW_FEE="${NEW_FEE:-10000}"
  SEND_JSON="$(cast send "$VOLATILITY_FEE_HOOK" "updateFee(bytes32,uint24)" "$POOL_ID" "$NEW_FEE" --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --json)"
  TXID="$(jq -r '.transactionHash // .hash' <<<"$SEND_JSON")"
  echo "Direct reactiveSender simulation txid: $TXID"
  echo "Direct reactiveSender simulation URL: $(tx_url "$TXID")"
else
  echo "Skipping direct simulation. Set DIRECT_SIMULATE=1 to send updateFee(bytes32,uint24) from PRIVATE_KEY."
fi

phase "Fresh origin swaps"
if [[ "${RUN_LIVE_SWAPS:-0}" == "1" ]]; then
  if [[ -z "${DEMO_TOKEN0:-}" || -z "${DEMO_TOKEN1:-}" ]]; then
    echo "RUN_LIVE_SWAPS=1 requires DEMO_TOKEN0 and DEMO_TOKEN1 for $NETWORK." >&2
    append_doc
    exit 1
  fi

  POOL_MANAGER="$POOL_MANAGER" \
    VOLATILITY_FEE_HOOK="$VOLATILITY_FEE_HOOK" \
    POOL_SWAP_TEST="$POOL_SWAP_TEST" \
    DEMO_TOKEN0="$DEMO_TOKEN0" \
    DEMO_TOKEN1="$DEMO_TOKEN1" \
    forge script script/RunDemoSwaps.s.sol:RunVolatilityFeeDemoSwaps --rpc-url "$RPC_URL" --broadcast --slow

  RUN_JSON="broadcast/RunDemoSwaps.s.sol/$CHAIN_ID/run-latest.json"
  LIVE_SWAP_TXS="$(jq -r '.transactions[] | .hash // empty' "$RUN_JSON" | while read -r hash; do tx_url "$hash"; done | paste -sd ' ' -)"
  LIVE_SWAP_HASHES="$(jq -r '.transactions[] | .hash // empty' "$RUN_JSON" | paste -sd ' ' -)"
  echo "Fresh origin txs:"
  printf '%s\n' "$LIVE_SWAP_TXS"

  LIVE_ORIGIN_SWAP_HASHES=""
  LIVE_ORIGIN_SWAP_BLOCKS=""
  SWAP_TOPIC="$(cast keccak "SwapPriceUpdate(bytes32,uint160,uint256)")"
  while read -r hash; do
    [[ -z "$hash" ]] && continue
    RECEIPT_JSON="$(cast receipt "$hash" --rpc-url "$RPC_URL" --json 2>/dev/null || true)"
    if jq -e --arg hook "$(lowercase "$VOLATILITY_FEE_HOOK")" --arg topic "$SWAP_TOPIC" \
      '.logs[]? | select((.address | ascii_downcase) == $hook and .topics[0] == $topic)' \
      >/dev/null 2>&1 <<<"$RECEIPT_JSON"; then
      LIVE_ORIGIN_SWAP_HASHES="${LIVE_ORIGIN_SWAP_HASHES}${LIVE_ORIGIN_SWAP_HASHES:+ }$hash"
      block_hex="$(jq -r '.blockNumber // empty' <<<"$RECEIPT_JSON")"
      if [[ -n "$block_hex" && "$block_hex" != "null" ]]; then
        LIVE_ORIGIN_SWAP_BLOCKS="${LIVE_ORIGIN_SWAP_BLOCKS}${LIVE_ORIGIN_SWAP_BLOCKS:+ }$((16#${block_hex#0x}))"
      fi
    fi
  done <<<"$(jq -r '.transactions[] | .hash // empty' "$RUN_JSON")"

  echo "Origin SwapPriceUpdate txs:"
  if [[ -n "$LIVE_ORIGIN_SWAP_HASHES" ]]; then
    for hash in $LIVE_ORIGIN_SWAP_HASHES; do
      echo "- $(tx_url "$hash")"
    done
  else
    echo "- none found in fresh run receipts"
  fi
else
  echo "Skipping fresh swaps. Set RUN_LIVE_SWAPS=1 to emit new SwapPriceUpdate events from the wired demo pool."
fi

phase "Lasna RSC live relay gate"
RSC_CODE="$(cast code "$VOLATILITY_FEE_RSC" --rpc-url "$LASNA_RPC" || true)"
if [[ "$RSC_CODE" == "0x" || -z "$RSC_CODE" ]]; then
  RSC_STATUS="not deployed/mined at $VOLATILITY_FEE_RSC yet"
  if [[ -n "${RSC_DEPLOY_TX:-}" ]]; then
    RSC_TX_STATUS="$(cast tx "$RSC_DEPLOY_TX" --rpc-url "$LASNA_RPC" 2>&1 | awk '/blockHash|blockNumber|hash|nonce|gasPrice/ {print}' | paste -sd '; ' - || true)"
  else
    RSC_TX_STATUS="unavailable: no RSC deploy tx configured"
  fi
  SUBSCRIPTION_STATUS="unavailable: $RSC_STATUS"
  OBSERVED_SWAPS_STATUS="unavailable: $RSC_STATUS"
  echo "RSC status: $RSC_STATUS"
  echo "RSC tx status: $RSC_TX_STATUS"
  echo "The destination hook, real PoolId, callback proxy, and RVM sender are wired."
  echo "A live Reactive relay proof still waits on Lasna code at the RSC address."
else
  RSC_STATUS="code present"
  RSC_TX_STATUS="mined or externally deployed; code present at RSC address"
  SUBSCRIPTION_STATUS="$(cast call "$VOLATILITY_FEE_RSC" "subscriptionConfigured()(bool)" --rpc-url "$LASNA_RPC" || true)"
  OBSERVED_SWAPS_STATUS="$(cast call "$VOLATILITY_FEE_RSC" "observedSwaps()(uint256)" --rpc-url "$LASNA_RPC" || true)"

  if [[ "${RUN_LIVE_SWAPS:-0}" == "1" ]]; then
    RSC_POLL_ATTEMPTS="${RSC_POLL_ATTEMPTS:-12}"
    RSC_POLL_INTERVAL="${RSC_POLL_INTERVAL:-10}"
    for ((attempt = 1; attempt <= RSC_POLL_ATTEMPTS; attempt++)); do
      if [[ "$OBSERVED_SWAPS_STATUS" != "0" && "$OBSERVED_SWAPS_STATUS" != *"Error"* ]]; then
        break
      fi
      echo "Waiting for Reactive ingestion attempt $attempt/$RSC_POLL_ATTEMPTS; observedSwaps=$OBSERVED_SWAPS_STATUS"
      sleep "$RSC_POLL_INTERVAL"
      OBSERVED_SWAPS_STATUS="$(cast call "$VOLATILITY_FEE_RSC" "observedSwaps()(uint256)" --rpc-url "$LASNA_RPC" || true)"
    done
  fi

  echo "RSC status: $RSC_STATUS"
  echo "RSC subscriptionConfigured(): $SUBSCRIPTION_STATUS"
  echo "RSC observedSwaps() via eth_call: $OBSERVED_SWAPS_STATUS"
  echo "Note: RNK RVM transactions below are the authoritative ReactVM execution proof; normal eth_call may not expose ReactVM state."
fi

phase "RNK RVM transaction proof"
RNK_FILTER_STATUS="not checked"
FILTERS_JSON="$(cast rpc rnk_getFilters --rpc-url "$LASNA_RPC" 2>/dev/null || true)"
if jq -e . >/dev/null 2>&1 <<<"$FILTERS_JSON"; then
  RNK_FILTER_MATCHES="$(jq -r \
    --arg hook "$(lowercase "$VOLATILITY_FEE_HOOK")" \
    --arg rsc "$(lowercase "$VOLATILITY_FEE_RSC")" \
    --arg rvm "$(lowercase "${RVM_SENDER:-}")" \
    --arg chain "$CHAIN_ID" \
    --arg topic "$(cast keccak "SwapPriceUpdate(bytes32,uint160,uint256)")" \
    '
      [
        .[]?
        | select((.ChainId | tostring) == $chain)
        | select(((.Contract // "") | ascii_downcase) == $hook)
        | select((.Topics[0] // "") == $topic)
        | .Configs[]?
        | select((((.Contract // "") | ascii_downcase) == $rsc) and (((.RvmId // "") | ascii_downcase) == $rvm) and (.Active == true))
      ] | length
    ' <<<"$FILTERS_JSON")"
  RNK_FILTER_STATUS="activeMatches=$RNK_FILTER_MATCHES chain=$CHAIN_ID hook=$VOLATILITY_FEE_HOOK rsc=$VOLATILITY_FEE_RSC rvm=${RVM_SENDER:-not set}"
else
  RNK_FILTER_STATUS="unavailable: rnk_getFilters failed"
fi
echo "$RNK_FILTER_STATUS"

if [[ -z "${RVM_SENDER:-}" ]]; then
  RVM_TX_STATUS="unavailable: RVM_SENDER not configured"
  RVM_TX_LINES=""
  echo "$RVM_TX_STATUS"
else
  RVM_INFO_JSON="$(cast rpc rnk_getVm "$RVM_SENDER" --rpc-url "$LASNA_RPC" 2>/dev/null || true)"
  if jq -e . >/dev/null 2>&1 <<<"$RVM_INFO_JSON"; then
    RVM_LAST_TX="$(jq -r '.lastTxNumber // "0x0"' <<<"$RVM_INFO_JSON")"
    RVM_START_TX="${RVM_START_TX:-$(rnk_tail_start "$RVM_LAST_TX")}"
    RVM_LIMIT="${RVM_LIMIT:-0x80}"
    RVM_TRANSACTIONS_JSON="$(cast rpc rnk_getTransactions "$RVM_SENDER" "$RVM_START_TX" "$RVM_LIMIT" --rpc-url "$LASNA_RPC" 2>/dev/null || true)"
    if jq -e . >/dev/null 2>&1 <<<"$RVM_TRANSACTIONS_JSON"; then
      RVM_TX_LINES="$(jq -r \
        --arg rsc "$(lowercase "$VOLATILITY_FEE_RSC")" \
        --arg chain "$CHAIN_ID" \
        --arg explorer "$EXPLORER" \
        --arg lasna "https://lasna.reactscan.net" \
        '
          map(select((.to | ascii_downcase) == $rsc and (.refChainId | tostring) == $chain))
          | .[]
          | "- RVM \(.number) tx: \($lasna)/tx/\(.hash) | ref origin: \($explorer)/tx/\(.refTx) | eventIndex: \(.refEventIndex) | status: \(.status)"
        ' <<<"$RVM_TRANSACTIONS_JSON")"
      RVM_MATCH_COUNT="$(jq -r \
        --arg rsc "$(lowercase "$VOLATILITY_FEE_RSC")" \
        --arg chain "$CHAIN_ID" \
        'map(select((.to | ascii_downcase) == $rsc and (.refChainId | tostring) == $chain)) | length' \
        <<<"$RVM_TRANSACTIONS_JSON")"
      RVM_TX_STATUS="lastTx=$RVM_LAST_TX searched=$RVM_START_TX..+$RVM_LIMIT matchingOriginExecutions=$RVM_MATCH_COUNT"
      echo "$RVM_TX_STATUS"
      if [[ -n "$RVM_TX_LINES" ]]; then
        printf '%s\n' "$RVM_TX_LINES"
      else
        echo "No RVM transactions found for this RSC/origin chain in the searched tail."
      fi
    else
      RVM_TX_STATUS="unavailable: rnk_getTransactions failed"
      RVM_TX_LINES=""
      echo "$RVM_TX_STATUS"
    fi
  else
    RVM_TX_STATUS="unavailable: rnk_getVm failed"
    RVM_TX_LINES=""
    echo "$RVM_TX_STATUS"
  fi
fi

phase "Destination callback proof"
CALLBACK_DEBT_RAW="$(cast call "$VOLATILITY_FEE_HOOK" "callbackDebt()(uint256)" --rpc-url "$RPC_URL" 2>&1 || true)"
HOOK_BALANCE="$(cast balance "$VOLATILITY_FEE_HOOK" --rpc-url "$RPC_URL" 2>&1 || true)"
CALLBACK_DEBT_STATUS="callbackDebt=$CALLBACK_DEBT_RAW hookBalanceWei=$HOOK_BALANCE"
echo "$CALLBACK_DEBT_STATUS"

FEE_UPDATED_STATUS="not searched"
FEE_UPDATED_LINES=""
if [[ -n "${LIVE_ORIGIN_SWAP_BLOCKS:-}" ]]; then
  min_block=""
  for block in $LIVE_ORIGIN_SWAP_BLOCKS; do
    if [[ -z "$min_block" || "$block" -lt "$min_block" ]]; then min_block="$block"; fi
  done
  search_to=$((min_block + ${CALLBACK_SEARCH_BLOCKS:-300}))
  latest_block_hex="$(cast block-number --rpc-url "$RPC_URL" 2>/dev/null || true)"
  if [[ "$latest_block_hex" =~ ^[0-9]+$ && "$latest_block_hex" -lt "$search_to" ]]; then
    search_to="$latest_block_hex"
  fi
  cursor="$min_block"
  while (( cursor <= search_to )); do
    chunk_to=$((cursor + 9))
    if (( chunk_to > search_to )); then chunk_to="$search_to"; fi
    chunk_logs="$(cast logs --from-block "$cursor" --to-block "$chunk_to" --address "$VOLATILITY_FEE_HOOK" "FeeUpdated(bytes32,uint24,uint24,uint256)" --rpc-url "$RPC_URL" 2>/dev/null || true)"
    if [[ -n "$chunk_logs" ]]; then
      FEE_UPDATED_LINES="${FEE_UPDATED_LINES}${FEE_UPDATED_LINES:+$'\n'}$chunk_logs"
    fi
    cursor=$((chunk_to + 1))
  done
  if [[ -n "$FEE_UPDATED_LINES" ]]; then
    FEE_UPDATED_STATUS="found FeeUpdated logs in blocks $min_block..$search_to"
    echo "$FEE_UPDATED_STATUS"
    printf '%s\n' "$FEE_UPDATED_LINES"
  else
    FEE_UPDATED_STATUS="no FeeUpdated logs found in blocks $min_block..$search_to"
    echo "$FEE_UPDATED_STATUS"
  fi
else
  echo "No fresh origin swap block list available; destination callback search skipped."
fi

phase "Reactive proof checklist"
cat <<EOF
Confirm these on explorers/RNK after real swaps:
  - Origin SwapPriceUpdate topic0: $(cast keccak "SwapPriceUpdate(bytes32,uint160,uint256)")
  - PoolId: $POOL_ID
  - Callback proxy wired into hook: $HOOK_CALLBACK_PROXY
  - RVM sender wired into hook: $HOOK_REACTIVE_SENDER
  - RSC status: $RSC_STATUS
  - RSC tx status: $RSC_TX_STATUS
  - RSC subscription tx: ${RSC_SUBSCRIPTION_TX:-not set}
  - RSC subscription tx status: $RSC_SUBSCRIPTION_TX_STATUS
  - RSC subscriptionConfigured(): $SUBSCRIPTION_STATUS
  - RSC observedSwaps() via eth_call: $OBSERVED_SWAPS_STATUS
  - RNK filter status: ${RNK_FILTER_STATUS:-not checked}
  - RNK RVM tx status: ${RVM_TX_STATUS:-not checked}
  - Destination callback status: ${FEE_UPDATED_STATUS:-not checked}
  - Callback debt status: ${CALLBACK_DEBT_STATUS:-not checked}
  - Destination FeeUpdated logs on hook: $(contract_url "$VOLATILITY_FEE_HOOK")#events

Txid classes to include in the final demo ledger:
  - Lasna RSC deploy tx: ${RSC_DEPLOY_TX:-not set}
  - Lasna subscription/config tx: ${RSC_SUBSCRIPTION_TX:-not set}
  - destination swap tx emitting SwapPriceUpdate
  - Lasna RVM tx processing the origin event
  - destination callback tx emitting FeeUpdated
EOF

append_doc
