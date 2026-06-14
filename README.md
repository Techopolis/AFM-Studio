# AFM Studio

AFM Studio is an open-source Mac and iOS app for trying, comparing, and benchmarking language models through Apple's Foundation Models framework.

The project is built for the OS 27 / Xcode 27 beta cycle. It focuses on the Apple Foundation Models path first: system models, Private Cloud Compute, and Core AI model bundles loaded through the Foundation Models provider support. MLX support is intentionally not wired into the app right now; it can return when Apple ships a Foundation Models-ready MLX language model package.

## What It Does

- Chat with models through `LanguageModelSession`.
- Select Apple system, Private Cloud Compute, and Core AI-backed models from one model registry.
- Add local Core AI model bundles from disk.
- Compare one prompt across multiple selected models.
- Run local benchmark suites and save results with SwiftData.
- Inspect Private Cloud Compute availability and quota status where supported.
- Parse model output channels so assistant text, final output, and thinking/reasoning traces do not render as raw protocol tags.
- Use a native SwiftUI interface with a macOS Settings scene, iOS Settings tab, SF Symbols, and VoiceOver-friendly row labels.

## Current Model Support

AFM Studio currently routes generation through Foundation Models sessions:

- `SystemLanguageModel.default`
- `PrivateCloudComputeLanguageModel` on supported OS 27 platforms
- `CoreAILanguageModel(resourcesAt:variant:kvCacheStrategy:)` when the Apple `coreai-models` package is linked

The built-in Core AI catalog includes:

- Gemma 4 E2B Core AI bundle from the community CoreAI model zoo
- Gemma 4 E4B Core AI bundle from the community CoreAI model zoo
- Gemma 3 4B Instruct from Apple's `coreai-models`
- Gemma 3 12B Instruct from Apple's `coreai-models`
- GPT-OSS 20B from Apple's `coreai-models`

Large model artifacts are not committed to this repository. Local exports belong under `CoreAIModelExports/`, which is ignored by Git.

## Requirements

- macOS with Xcode 27 beta installed at:

  ```bash
  /Applications/Xcode-beta.app/Contents/Developer
  ```

- Apple OS 27 SDKs for building the app.
- SwiftUI, SwiftData, FoundationModels, and the Apple `coreai-models` Swift package dependency.
- A paid Apple Developer Program or Apple Developer Enterprise Program team for entitlement-backed Foundation Models features.
- Optional for local model export: `uv`, expected by `scripts/export-coreai-models.sh`.

## Private Cloud Compute Entitlement

Private Cloud Compute and adapter-backed Foundation Models features require a signed app identifier with the Apple-approved Foundation Models capability before they can be used outside the basic local development path. In the Xcode 27 beta developer portal metadata, the requestable capability is named `Foundation Model Adapter` and it adds the boolean entitlement `com.apple.developer.foundation-model-adapter`.

To enable it for your own builds:

1. Sign in to the Apple Developer account that owns your app identifier.
2. Request the Foundation Models framework adapter entitlement from Apple: [Foundation Models framework adapter entitlement request](https://developer.apple.com/contact/request/foundation-models-framework-adapter-entitlement).
3. After approval, open `AFM Studio.xcodeproj` in Xcode 27 beta.
4. Select the `AFM Studio` app target, then open `Signing & Capabilities`.
5. Choose your development team and a bundle identifier that has the approved capability.
6. Add the `Foundation Model Adapter` capability. If Xcode exposes a more specific Foundation Models or Private Cloud Compute capability in a later beta, use the capability name Xcode shows for that SDK.
7. Let Xcode create or update the app entitlements file and provisioning profile. The entitlement file should contain the key Xcode adds, currently `com.apple.developer.foundation-model-adapter`.
8. Build and run on a supported OS 27 Mac or device, then refresh the model registry in AFM Studio. The Private Cloud Compute row should report availability and quota through `PrivateCloudComputeLanguageModel.availability` and `quotaUsage`.

Do not commit personal provisioning profiles, signing certificates, or Xcode user state. Commit only project and entitlement-file changes that are required for the shared open-source target.

## Getting Started

From the repository root, build with the beta toolchain:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
/Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild \
  -project "AFM Studio.xcodeproj" \
  -scheme "AFM Studio" \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/AFMStudioDerivedData \
  build
```

For a generic iOS device compile check:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
/Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild \
  -project "AFM Studio.xcodeproj" \
  -scheme "AFM Studio" \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/AFMStudioDerivedData-iOS \
  CODE_SIGNING_ALLOWED=NO \
  build
```

The iOS Simulator path can be limited by the beta SDK and Apple's Core AI package availability. Prefer macOS and generic iOS device builds for repository verification until the simulator SDK includes the needed Core AI framework surface.

## Local Core AI Models

AFM Studio can detect installed Core AI model bundles from app Application Support:

```text
~/Library/Containers/online.techopolis.afmstudio/Data/Library/Application Support/AFM Studio/CoreAIModels/
```

To export Apple's supported Core AI presets locally, first make sure the `coreai-models` package checkout exists under the derived data path, then run:

```bash
bash scripts/export-coreai-models.sh gemma3-4b
bash scripts/export-coreai-models.sh gemma3-12b
bash scripts/export-coreai-models.sh gpt-oss-20b
```

Or export all three:

```bash
bash scripts/export-coreai-models.sh all
```

To install exported bundles into the macOS app container for local testing:

```bash
bash scripts/install-coreai-models-local.sh all
```

The install script currently supports:

- `gemma3-4b`
- `gemma3-12b`
- `gpt-oss-20b`
- `all`

## Project Layout

```text
AFM Studio/
  AFMStudioApp.swift                 App entry point and scenes
  ContentView.swift                  Root host
  Models/                            SwiftData records and model metadata
  Services/                          Registry, session factory, stores, Core AI support
  Views/                             SwiftUI chat, models, compare, benchmarks, settings
scripts/
  export-coreai-models.sh            Local Apple Core AI export helper
  install-coreai-models-local.sh     Local app-container install helper
docs/superpowers/
  specs/                             Design notes
  plans/                             Implementation plans
```

## Development Notes

- Keep generation routed through `LanguageModelSession`.
- Keep provider-specific setup isolated behind services such as `SessionFactory`, `ModelRegistry`, and `CoreAILanguageModelSupport`.
- Do not commit exported model bundles, derived data, or local app-container artifacts.
- Prefer native SwiftUI controls and SF Symbols.
- Keep VoiceOver behavior explicit on custom rows, cards, and icon-heavy controls.
- Use Xcode beta for verification unless a task explicitly targets the stable Xcode install.

## Verification

Before opening a pull request, run:

```bash
git diff --check

DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
/Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild \
  -project "AFM Studio.xcodeproj" \
  -scheme "AFM Studio" \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/AFMStudioDerivedData \
  build

DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
/Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild \
  -project "AFM Studio.xcodeproj" \
  -scheme "AFM Studio" \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/AFMStudioDerivedData-iOS \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Roadmap

- Improve Core AI bundle download and installation flows.
- Add richer benchmark metrics, including throughput when APIs expose enough timing data.
- Add quota and usage views for supported Foundation Models providers.
- Revisit MLX when Apple provides a Foundation Models-compatible MLX language model package.
- Add server-provider support only through Foundation Models provider interfaces.

## License

AFM Studio is intended to be open source. Add a `LICENSE` file before public release so contributors and users know the exact terms.
