#!/bin/bash
# tests/unit/test-codex-native-subagents.sh
# Verifies Codex native subagent prompt preparation is wired into all dispatch paths.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/../helpers/test-framework.sh"

ORCH="$PROJECT_ROOT/scripts/orchestrate.sh"
DISPATCH="$PROJECT_ROOT/scripts/lib/dispatch.sh"
SPAWN="$PROJECT_ROOT/scripts/lib/spawn.sh"
SYNC="$PROJECT_ROOT/scripts/lib/agent-sync.sh"
WORKFLOWS="$PROJECT_ROOT/scripts/lib/workflows.sh"
CODEX_AGENTS_DIR="$PROJECT_ROOT/.codex/agents"

test_suite "Codex Native Subagents"

test_preamble_allows_native_subagents() {
    test_case "preamble: Codex preamble allows native subagent delegation"
    if grep -q 'unless it explicitly instructs you to use native Codex subagents first' "$ORCH"; then
        test_pass
    else
        test_fail "Codex preamble should preserve explicit native subagent instructions"
    fi
}

test_dispatch_helpers_exist() {
    test_case "dispatch: helper functions exist"
    if grep -q '^codex_custom_agent_file()' "$DISPATCH" && \
       grep -q '^resolve_codex_native_agent_spec()' "$DISPATCH" && \
       grep -q '^build_codex_native_subagent_prompt()' "$DISPATCH" && \
       grep -q '^prepare_codex_native_prompt()' "$DISPATCH"; then
        test_pass
    else
        test_fail "Expected Codex native helper functions in dispatch.sh"
    fi
}

test_prepare_prompt_prefers_project_agent() {
    test_case "dispatch: prepare_codex_native_prompt prefers project-scoped custom agents"
    local output
    output="$(
        (
            PROJECT_ROOT="$PROJECT_ROOT"
            SUPPORTS_AGENT_TYPE_ROUTING=false
            source "$DISPATCH"
            prepare_codex_native_prompt "codex" "architect" "develop" "Design the backend." "backend-architect"
        )
    )"

    if [[ "$output" == *'project-scoped custom agent "backend-architect"'* ]] && \
       [[ "$output" == *'.codex/agents/backend-architect.toml'* ]]; then
        test_pass
    else
        test_fail "prepare_codex_native_prompt should target backend-architect project agent"
    fi
}

test_prepare_prompt_can_be_disabled() {
    test_case "dispatch: OCTOPUS_CODEX_NATIVE_SUBAGENTS=off disables native delegation prompt"
    local output
    output="$(
        (
            PROJECT_ROOT="$PROJECT_ROOT"
            OCTOPUS_CODEX_NATIVE_SUBAGENTS=off
            SUPPORTS_AGENT_TYPE_ROUTING=false
            source "$DISPATCH"
            prepare_codex_native_prompt "codex" "architect" "develop" "Design the backend." "backend-architect"
        )
    )"

    if [[ "$output" == "Design the backend." ]]; then
        test_pass
    else
        test_fail "native delegation prompt should be bypassed when disabled"
    fi
}

test_all_dispatch_paths_use_prepare_helper() {
    test_case "wiring: spawn, sync, and workflows call prepare_codex_native_prompt"
    if grep -q 'prepare_codex_native_prompt' "$SPAWN" && \
       grep -q 'prepare_codex_native_prompt' "$SYNC" && \
       grep -q 'prepare_codex_native_prompt' "$WORKFLOWS"; then
        test_pass
    else
        test_fail "Expected all Codex dispatch paths to call prepare_codex_native_prompt"
    fi
}

test_project_codex_agents_exist() {
    test_case "project: .codex custom agents are present"
    if [[ -d "$CODEX_AGENTS_DIR" ]] && [[ -f "$CODEX_AGENTS_DIR/backend-architect.toml" ]] && [[ -f "$CODEX_AGENTS_DIR/code-reviewer.toml" ]]; then
        test_pass
    else
        test_fail "Expected .codex/agents with project-scoped Codex agents"
    fi
}

test_preamble_allows_native_subagents
test_dispatch_helpers_exist
test_prepare_prompt_prefers_project_agent
test_prepare_prompt_can_be_disabled
test_all_dispatch_paths_use_prepare_helper
test_project_codex_agents_exist

test_summary
