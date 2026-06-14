# Contributing to AFM Studio

Thanks for helping build AFM Studio. This project is early, beta-SDK-dependent, and model-runtime-heavy, so the best contributions are small, well verified, and honest about platform limitations.

## Development Setup

Use Xcode 27 beta unless a maintainer explicitly asks for the stable Xcode install:

```bash
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
```

Open the project with:

```bash
open -a Xcode-beta "AFM Studio.xcodeproj"
```

Or build from the command line:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
/Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild \
  -project "AFM Studio.xcodeproj" \
  -scheme "AFM Studio" \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/AFMStudioDerivedData \
  build
```

## Pull Request Checklist

Before opening a PR, run:

```bash
git diff --check
```

Then run the platform builds:

```bash
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

In the PR description, include:

- What changed.
- Why it changed.
- What commands you ran.
- Any beta SDK limitations, unavailable frameworks, or simulator-only issues.
- Screenshots or short screen recordings for visible UI changes.

## Code Style

- Follow the existing SwiftUI and SwiftData structure.
- Keep files focused by feature or responsibility.
- Prefer native SwiftUI state and Observation.
- Prefer semantic platform colors and materials over fixed custom colors.
- Use SF Symbols for common actions and statuses.
- Use text labels with symbols for primary controls unless the surrounding platform chrome clearly expects icon-only controls.
- Keep cards and rows visually restrained. This is a studio/tool UI, not a landing page.
- Keep comments rare and useful.

## Foundation Models Rules

AFM Studio's core invariant is that generation should flow through Apple's Foundation Models framework.

- Route chat, compare, and benchmark generation through `LanguageModelSession`.
- Add provider-specific setup behind `SessionFactory` or focused support services.
- Do not add a parallel non-FoundationModels chat client for OpenAI, Ollama, MLX, or other providers.
- If a provider requires custom support, implement it as a Foundation Models provider/executor path.
- Preserve channel/tag parsing behavior so model protocol markers do not leak into user-visible assistant output.

## Foundation Models Entitlement

Private Cloud Compute and custom Foundation Models adapter work must include clear entitlement notes. Xcode 27 beta currently exposes the requestable Apple Developer capability as `Foundation Model Adapter`, backed by the boolean entitlement `com.apple.developer.foundation-model-adapter`.

When changing this area:

- Request approval through Apple's entitlement form before expecting the model to run: [Foundation Models framework adapter entitlement request](https://developer.apple.com/contact/request/foundation-models-framework-adapter-entitlement).
- Add the capability through Xcode's `Signing & Capabilities` UI instead of hand-typing entitlement keys.
- Commit only the shared project and entitlement-file changes that are needed for AFM Studio.
- Do not commit provisioning profiles, certificates, personal team identifiers, or Xcode user state.
- Mention in the PR whether `PrivateCloudComputeLanguageModel.availability` and `quotaUsage` were tested on a supported OS 27 Mac or device.
- If Apple renames the beta capability or introduces a separate Private Cloud Compute capability, update `README.md`, this guide, and the Xcode project together.

## Model Artifacts

Do not commit model weights or exported model bundles.

Ignored local exports belong under:

```text
CoreAIModelExports/
```

Local macOS test installs belong under the app container:

```text
~/Library/Containers/online.techopolis.afmstudio/Data/Library/Application Support/AFM Studio/CoreAIModels/
```

If your change depends on a model bundle, document:

- Source repository or model card.
- License or usage terms.
- Export command or download process.
- Bundle size.
- Platforms tested.
- Whether the app can detect and run it.

## Core AI Workflow

Use the helper scripts for local Apple Core AI exports:

```bash
bash scripts/export-coreai-models.sh gemma3-4b
bash scripts/export-coreai-models.sh gemma3-12b
bash scripts/export-coreai-models.sh gpt-oss-20b
bash scripts/install-coreai-models-local.sh all
```

If you add catalog entries, update the descriptor metadata and status lines so the Models and Settings views tell users exactly what is available, installed, or still requires setup.

## UI and Accessibility

AFM Studio should feel native on both macOS and iOS.

- Use `Settings` scenes and `SettingsLink` on macOS.
- Keep iOS settings reachable through in-app navigation because `SettingsLink` is unavailable on iOS.
- Use native list/sidebar behavior for navigation.
- Add clear accessibility labels and values for custom rows and cards.
- Hide decorative symbols from accessibility with `.accessibilityHidden(true)`.
- Avoid exposing multiple small controls to VoiceOver when one coherent row with a clear action is better.
- Make the visible control do the same thing as its VoiceOver default action.
- Do not rely on color alone for status; pair status color with text or a symbol.
- Rebuild after SwiftUI UI changes on both macOS and generic iOS.

## Branches and Commits

- Keep PRs focused.
- Avoid unrelated refactors.
- Do not commit Xcode user state such as `xcuserdata` unless a maintainer explicitly asks for it.
- Do not revert someone else's uncommitted work.
- Use clear commit messages, for example:

```text
Add Core AI model catalog metadata
Polish chat sidebar accessibility
Document local Core AI export workflow
```

## Reporting Issues

When filing an issue, include:

- macOS/iOS version.
- Xcode beta version.
- Device or simulator target.
- Selected model.
- Whether the model bundle is installed.
- Reproduction steps.
- Relevant build or runtime logs.

For model runtime issues, also include the exact model source and bundle path shape, but do not attach model weights unless the license permits it and a maintainer requests it.

## Security

Do not post secrets, API keys, provisioning profiles, signing identities, private model URLs, or proprietary model artifacts in issues or PRs.

If a future provider integration handles API keys, store secrets in Keychain or another platform security surface. Do not store plaintext credentials in SwiftData records, logs, README snippets, or tests.

## Documentation

Keep documentation in sync with the app:

- Update `README.md` when setup, model support, or verification commands change.
- Update `CONTRIBUTING.md` when contributor workflow changes.
- Put implementation notes and planning material under `docs/`.
- Prefer concrete commands over vague instructions.
