# Core AI Model Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Core AI bundle-backed models to AFM Studio while leaving MLX disabled until Apple publishes a FoundationModels-ready MLX package.

**Architecture:** AFM Studio keeps Chat, Compare, and Benchmarks routed through `LanguageModelSession`. Core AI support is isolated in a small support service that conditionally imports `CoreAILanguageModels`, resolves a local model bundle URL from the stored model descriptor, and creates `CoreAILanguageModel(resourcesAt:)` when available.

**Tech Stack:** SwiftUI, SwiftData, FoundationModels, Apple `coreai-models` Swift package product `CoreAILM`, Xcode 27 beta.

---

### Task 1: Wire Apple Core AI Package

**Files:**
- Modify: `AFM Studio.xcodeproj/project.pbxproj`

- [x] **Step 1: Add package dependency**

Add `https://github.com/apple/coreai-models.git` as a Swift package reference on branch `main` and link product `CoreAILM` to the `AFM Studio` target.

- [x] **Step 2: Limit supported platforms to Mac and iOS**

Set target `SUPPORTED_PLATFORMS` to `iphoneos iphonesimulator macosx` and `TARGETED_DEVICE_FAMILY` to `1,2` so the app target matches the requested Mac/iOS scope and the Core AI package platform set.

- [x] **Step 3: Resolve packages**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer /Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild -resolvePackageDependencies -project "AFM Studio.xcodeproj" -scheme "AFM Studio" -derivedDataPath /tmp/AFMStudioDerivedData
```

Actual: package resolution succeeds and writes `Package.resolved`, pinning `coreai-models` to `main` revision `02a8edd`.

### Task 2: Add Core AI Session Support

**Files:**
- Create: `AFM Studio/Services/CoreAILanguageModelSupport.swift`
- Modify: `AFM Studio/Models/ModelDescriptor.swift`
- Modify: `AFM Studio/Models/PersistenceModels.swift`
- Modify: `AFM Studio/Services/ModelRegistry.swift`
- Modify: `AFM Studio/Services/SessionFactory.swift`
- Modify: `AFM Studio/Services/ChatStore.swift`
- Modify: `AFM Studio/Services/CompareStore.swift`
- Modify: `AFM Studio/Services/BenchmarkStore.swift`

- [x] **Step 1: Extend model metadata**

Add optional `resourcePath`, `resourceBookmark`, and `variant` fields to user model records and descriptors so Core AI models can refer to local bundle folders.

- [x] **Step 2: Add conditional Core AI factory**

Create `CoreAILanguageModelSupport` with `#if canImport(CoreAILanguageModels)`, a status line, and an async `makeSession(for:)` that resolves the bundle URL and returns `LanguageModelSession(model: CoreAILanguageModel(resourcesAt:variant:))`.

- [x] **Step 3: Make session construction async**

Change `SessionFactory.makeSession(for:)` to `async throws` and update Chat, Compare, and Benchmark stores to call `try await`.

- [x] **Step 4: Build**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer /Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild -project "AFM Studio.xcodeproj" -scheme "AFM Studio" -destination 'platform=macOS' -derivedDataPath /tmp/AFMStudioDerivedData build
```

Actual: macOS build succeeds.

### Task 3: Add Core AI Bundle Import UI

**Files:**
- Modify: `AFM Studio/Views/Models/ModelLibraryView.swift`
- Modify: `AFM Studio/Views/Models/ModelPickerView.swift`
- Modify: `AFM Studio/Views/Settings/StudioSettingsView.swift`

- [x] **Step 1: Update Add Model sheet**

When lane is Core AI, show a folder picker for the model bundle and save a security-scoped bookmark when available. Require a selected bundle before enabling Add.

- [x] **Step 2: Surface Core AI status**

Show whether `CoreAILanguageModels` is linked in Models and Settings. User-added Core AI models should become sendable when the package is linked and a bundle path exists.

- [x] **Step 3: Final verification**

Run macOS and iOS builds:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer /Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild -project "AFM Studio.xcodeproj" -scheme "AFM Studio" -destination 'platform=macOS' -derivedDataPath /tmp/AFMStudioDerivedData build
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer /Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild -project "AFM Studio.xcodeproj" -scheme "AFM Studio" -destination 'generic/platform=iOS' -derivedDataPath /tmp/AFMStudioDerivedData-iOSDevice CODE_SIGNING_ALLOWED=NO build
```

Actual: macOS and generic iOS device builds succeed. The iOS Simulator build fails in Apple's `coreai-models` package because `CoreAI.framework` is not present in the iPhoneSimulator 27.0 SDK in this Xcode beta.

### Task 4: Replace Core AI Placeholder With Researched Catalog Entries

**Files:**
- Create: `AFM Studio/Services/CoreAIModelCatalog.swift`
- Modify: `AFM Studio/Models/ModelDescriptor.swift`
- Modify: `AFM Studio/Models/PersistenceModels.swift`
- Modify: `AFM Studio/Services/ModelRegistry.swift`
- Modify: `AFM Studio/Views/Models/ModelLibraryView.swift`

- [x] **Step 1: Add source-labeled Core AI catalog**

Add `CoreAIModelCatalog` with real entries for:

- Gemma 4 E2B and Gemma 4 E4B from the community CoreAI model zoo.
- Gemma 3 4B Instruct, Gemma 3 12B Instruct, and GPT-OSS 20B from Apple's `coreai-models` registry.

- [x] **Step 2: Persist preset identity**

Add `catalogID` to saved user model records and add catalog source, model-card URL, download URL, export command, and platform summary metadata to descriptors.

- [x] **Step 3: Update Add Model UI**

Show a Core AI preset picker, source metadata, bundle/download URL, export command, and the existing bundle chooser. The built-in model rows now reflect actual catalog entries instead of a generic Gemma placeholder.

- [x] **Step 4: Verification**

Run a focused Swift typecheck probe against the catalog IDs and metadata:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer /usr/bin/xcrun swiftc -typecheck -parse-as-library "AFM Studio/Models/ModelDescriptor.swift" "AFM Studio/Models/PersistenceModels.swift" "AFM Studio/Services/CoreAIModelCatalog.swift" "AFM Studio/Services/FoundationModelStatusFormatting.swift" "AFM Studio/Services/MLXFoundationModelSupport.swift" "AFM Studio/Services/CoreAILanguageModelSupport.swift" "AFM Studio/Services/SessionFactory.swift" "AFM Studio/Services/ModelRegistry.swift" /private/tmp/AFMStudioCoreAICatalogProbe.swift
```

Actual: typecheck probe succeeds.

### Task 5: Remove MLX Surface and Export Apple Core AI Models Locally

**Files:**
- Delete: `AFM Studio/Services/MLXFoundationModelSupport.swift`
- Modify: `AFM Studio/Models/ModelDescriptor.swift`
- Modify: `AFM Studio/Models/PersistenceModels.swift`
- Modify: `AFM Studio/Services/ModelRegistry.swift`
- Modify: `AFM Studio/Services/SessionFactory.swift`
- Modify: `AFM Studio/Views/Models/ModelLibraryView.swift`
- Modify: `AFM Studio/Views/Settings/StudioSettingsView.swift`
- Create: `.gitignore`
- Create: `scripts/export-coreai-models.sh`

- [x] **Step 1: Remove MLX app support**

Remove the Local MLX lane, MLX imports, MLX settings status, and the built-in MLX Gemma ID until Apple ships a supported FoundationModels `MLXLanguageModel` package.

- [x] **Step 2: Add repeatable local export workflow**

Add `scripts/export-coreai-models.sh` and keep large local bundles under ignored `CoreAIModelExports/`.

- [x] **Step 3: Export and smoke-test official Apple Core AI presets**

Exported and validated with Apple's `llm-runner`:

- `google/gemma-3-4b-it` -> `CoreAIModelExports/gemma-3-4b-it/gemma_3_4b_it_4bit_dynamic` (2.1 GB)
- `google/gemma-3-12b-it` -> `CoreAIModelExports/gemma-3-12b-it/gemma_3_12b_it_4bit_dynamic` (6.2 GB)
- `openai/gpt-oss-20b` -> `CoreAIModelExports/gpt-oss-20b/gpt_oss_20b_dynamic` (13 GB)

All three bundles loaded locally through `llm-runner` and generated a short greeting.

- [x] **Step 4: Final verification**

Run:

```bash
! rg -n 'localMLX|MLXFoundationModelSupport|MLXLanguageModel|MLXFoundationModels|BuiltInModelID\.gemma4E2B\b|mlx\.' 'AFM Studio'
git diff --check
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer /Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild -project "AFM Studio.xcodeproj" -scheme "AFM Studio" -destination 'platform=macOS' -derivedDataPath /private/tmp/AFMStudioDerivedData build
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer /Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild -project "AFM Studio.xcodeproj" -scheme "AFM Studio" -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/AFMStudioDerivedData-iOSDevice CODE_SIGNING_ALLOWED=NO build
```

Actual: MLX absence check passes, diff whitespace check passes, macOS build succeeds, and generic iOS device build succeeds.

### Task 6: Make Locally Exported Core AI Models Usable In The App

**Root cause:** Built-in Core AI catalog rows were metadata-only. They did not have a bundle path or bookmark, so the registry correctly marked them `requiresSetup` and `SessionFactory` would not run them.

**Files:**
- Create: `AFM Studio/Services/CoreAIModelStore.swift`
- Modify: `AFM Studio/Services/CoreAIModelCatalog.swift`
- Modify: `AFM Studio/Services/ModelRegistry.swift`
- Create: `scripts/install-coreai-models-local.sh`

- [x] **Step 1: Add installed bundle paths to Apple Core AI catalog entries**

Gemma 3 4B, Gemma 3 12B, and GPT-OSS 20B now point at their expected installed bundle subpaths under `CoreAIModels/`.

- [x] **Step 2: Add sandbox-readable model store**

`CoreAIModelStore` resolves installed bundles from Application Support. On macOS it also checks the app sandbox container path for `online.techopolis.afmstudio`, which lets local command-line installs be detected by the sandboxed app.

- [x] **Step 3: Install current exports into the app container**

Ran:

```bash
bash scripts/install-coreai-models-local.sh all
```

Installed all three exported Apple Core AI bundles to:

```text
~/Library/Containers/online.techopolis.afmstudio/Data/Library/Application Support/AFM Studio/CoreAIModels/
```

- [x] **Step 4: Make catalog descriptors sendable when installed**

`ModelRegistry` now sets a built-in Core AI descriptor's `resourcePath` and marks it `experimental` when the bundle is installed and `CoreAILanguageModels` is linked in the app target.

- [x] **Step 5: Verification**

Focused checks confirmed all three installed bundles resolve from the app container. macOS and generic iOS device builds with Xcode beta both succeed.
