#!/bin/bash
# tests/unit/test-model-resolver-env-precedence.sh
# Verifies env overrides beat the persistent model cache.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/../helpers/test-framework.sh"

MODEL_RESOLVER="$PROJECT_ROOT/scripts/lib/model-resolver.sh"

test_suite "Model Resolver Env Precedence"

test_env_override_beats_cache() {
    test_case "resolver: OCTOPUS_GEMINI_MODEL overrides persistent cache"

    local test_home="$TEST_TMP_DIR/home"
    local test_user="octo-env"
    local test_session="resolver-env"
    local cache_file="/tmp/octo-model-cache-${test_user}-${test_session}.json"
    mkdir -p "$test_home/.claude-octopus/config"

    cat > "$test_home/.claude-octopus/config/providers.json" <<'EOF'
{
  "version": "3.0",
  "providers": {
    "gemini": {
      "default": "gemini-3.1-pro-preview"
    }
  },
  "routing": {},
  "tiers": {},
  "overrides": {}
}
EOF

    cat > "$cache_file" <<'EOF'
{
  "MC_gemini_A_gemini_P_develop_R_implementer": "gemini-3.1-pro-preview"
}
EOF

    local output
    output="$(
        HOME="$test_home" \
        USER="$test_user" \
        CLAUDE_CODE_SESSION="$test_session" \
        OCTOPUS_GEMINI_MODEL="gemini-2.5-flash" \
        bash -lc 'source "'"$MODEL_RESOLVER"'"; resolve_octopus_model gemini gemini develop implementer'
    )"

    rm -f "$cache_file"

    if [[ "$output" == "gemini-2.5-flash" ]]; then
        test_pass
    else
        test_fail "Expected env override to win over cache, got: $output"
    fi
}

test_env_override_beats_cache

test_summary
