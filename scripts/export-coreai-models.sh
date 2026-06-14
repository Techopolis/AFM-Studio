#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COREAI_MODELS_DIR="${COREAI_MODELS_DIR:-/private/tmp/AFMStudioDerivedData/SourcePackages/checkouts/coreai-models}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/CoreAIModelExports}"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"
UV="${UV:-/opt/homebrew/bin/uv}"
export DEVELOPER_DIR

mkdir -p "$OUTPUT_ROOT"

run_export() {
    local model_id="$1"
    local output_name="$2"

    "$UV" run coreai.llm.export "$model_id" \
        --output-dir "$OUTPUT_ROOT/$output_name"
}

cd "$COREAI_MODELS_DIR"

case "${1:-all}" in
    gemma3-4b)
        run_export "google/gemma-3-4b-it" "gemma-3-4b-it"
        ;;
    gemma3-12b)
        run_export "google/gemma-3-12b-it" "gemma-3-12b-it"
        ;;
    gpt-oss-20b)
        run_export "openai/gpt-oss-20b" "gpt-oss-20b"
        ;;
    all)
        run_export "google/gemma-3-4b-it" "gemma-3-4b-it"
        run_export "google/gemma-3-12b-it" "gemma-3-12b-it"
        run_export "openai/gpt-oss-20b" "gpt-oss-20b"
        ;;
    *)
        echo "Usage: $0 [gemma3-4b|gemma3-12b|gpt-oss-20b|all]" >&2
        exit 64
        ;;
esac
