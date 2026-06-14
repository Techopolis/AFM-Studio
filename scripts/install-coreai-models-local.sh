#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPORT_ROOT="${EXPORT_ROOT:-$ROOT_DIR/CoreAIModelExports}"
BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER:-online.techopolis.afmstudio}"
APP_CONTAINER_DATA="${APP_CONTAINER_DATA:-$HOME/Library/Containers/$BUNDLE_IDENTIFIER/Data}"
MODEL_ROOT="${MODEL_ROOT:-$APP_CONTAINER_DATA/Library/Application Support/AFM Studio/CoreAIModels}"

install_model() {
    local export_name="$1"
    local bundle_name="$2"
    local source="$EXPORT_ROOT/$export_name/$bundle_name"
    local destination="$MODEL_ROOT/$export_name/$bundle_name"

    if [[ ! -d "$source" ]]; then
        echo "Missing exported model: $source" >&2
        exit 66
    fi

    mkdir -p "$(dirname "$destination")"
    /usr/bin/ditto "$source" "$destination"
    echo "Installed $export_name -> $destination"
}

case "${1:-all}" in
    gemma3-4b)
        install_model "gemma-3-4b-it" "gemma_3_4b_it_4bit_dynamic"
        ;;
    gemma3-12b)
        install_model "gemma-3-12b-it" "gemma_3_12b_it_4bit_dynamic"
        ;;
    gpt-oss-20b)
        install_model "gpt-oss-20b" "gpt_oss_20b_dynamic"
        ;;
    all)
        install_model "gemma-3-4b-it" "gemma_3_4b_it_4bit_dynamic"
        install_model "gemma-3-12b-it" "gemma_3_12b_it_4bit_dynamic"
        install_model "gpt-oss-20b" "gpt_oss_20b_dynamic"
        ;;
    *)
        echo "Usage: $0 [gemma3-4b|gemma3-12b|gpt-oss-20b|all]" >&2
        exit 64
        ;;
esac
