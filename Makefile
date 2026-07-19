SHELL := /bin/bash
.DEFAULT_GOAL := help

SWIFT_FORMAT_PATHS := Sources Tests CLI Apps
VERSION ?=
IOS_DESTINATION ?=

.PHONY: help docs-list format lint generate-project \
	assert-swift-toolchain assert-generated-project assert-hardened-runtime \
	assert-sparkle-info-plist \
	test-linux test-session test-persistence test-control test-cli test-platform-gating \
	log-apple-toolchain select-xcode select-ios-simulator \
	build-macos build-ios test-macos-integration smoke-macos smoke-ios archive-macos \
	verify-linux verify-apple release-check require-macos

help: ## Show this help (auto-generated from target comments)
	@echo "Focus Makefile targets:"
	@grep -hE '^[a-zA-Z0-9_.-]+:.*## ' $(MAKEFILE_LIST) \
		| awk -F':.*## ' '{printf "  %-24s %s\n", $$1, $$2}'

docs-list: ## Validate and list docs frontmatter
	node Scripts/docs-list.mjs

format: ## Format Swift sources in place (swift format)
	swift format --in-place --recursive $(SWIFT_FORMAT_PATHS)

lint: ## Format-lint + concurrency-safety scan
	swift format lint --recursive $(SWIFT_FORMAT_PATHS)
	swift Scripts/check-concurrency-safety.swift

assert-swift-toolchain: ## Assert pinned Swift 6.3.3 toolchain
	./Scripts/assert-swift-toolchain.sh

generate-project: ## Generate Focus.xcodeproj via pinned XcodeGen
	swift run --package-path tools/projectgen xcodegen generate --spec project.yml --project .

assert-generated-project: ## Assert objectVersion=90 and project untracked
	./Scripts/assert-generated-project.sh

assert-hardened-runtime: ## Assert FocusMac + FocusCLI enable hardened runtime
	./Scripts/assert-hardened-runtime.sh

assert-sparkle-info-plist: ## Assert Sparkle keys live in FocusMac Info.plist
	./Scripts/assert-sparkle-info-plist.sh

test-linux: ## Run portable SwiftPM tests (swift test)
	swift test

test-session: ## Test FocusSession (timing, transitions)
	swift test --filter FocusSessionTests

test-persistence: ## Test FocusPersistence (SQLite atomicity)
	swift test --filter FocusPersistenceIntegrationTests

test-control: ## Test FocusControl (framing, DTOs)
	swift test --filter FocusControlTests

test-cli: ## Test focus CLI over a real Unix socket
	swift test --filter FocusCLIIntegrationTests

test-platform-gating: ## Test platform-gating seams stay portable
	swift test --filter FocusPlatformGatingTests

require-macos:
	@if [[ "$$(uname -s)" != "Darwin" ]]; then \
		echo "error: this target requires macOS with Xcode 26.6" >&2; \
		exit 1; \
	fi

log-apple-toolchain: require-macos ## Log Apple toolchain / runner image
	./Scripts/log-apple-toolchain.sh

select-xcode: require-macos ## Select pinned Xcode (reads .xcode-version)
	./Scripts/select-xcode.sh

select-ios-simulator: require-macos ## Resolve and boot an iOS 26 simulator
	./Scripts/select-ios-simulator.sh

build-macos: require-macos select-xcode generate-project assert-generated-project ## Generate + build FocusMac
	xcodebuild -project Focus.xcodeproj -scheme FocusMac -destination "generic/platform=macOS" build

build-ios: require-macos select-xcode generate-project assert-generated-project ## Generate + build FocusIOS
	xcodebuild -project Focus.xcodeproj -scheme FocusIOS -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build

test-macos-integration: require-macos select-xcode generate-project ## Darwin IPC / adapter integration tests
	xcodebuild -project Focus.xcodeproj -scheme FocusMacIntegrationTests -destination "platform=macOS" test

smoke-macos: require-macos select-xcode generate-project ## macOS UI launch smoke
	xcodebuild -project Focus.xcodeproj -scheme FocusMacUITests -destination "platform=macOS" test

smoke-ios: require-macos select-xcode generate-project ## iOS UI launch smoke (boots simulator)
	@dest="$(IOS_DESTINATION)"; \
	if [[ -z "$$dest" ]]; then \
		dest="$$(./Scripts/select-ios-simulator.sh)"; \
	fi; \
	echo "smoke-ios: destination=$$dest"; \
	xcodebuild -project Focus.xcodeproj -scheme FocusIOSUITests -destination "$$dest" CODE_SIGNING_ALLOWED=NO test

archive-macos: require-macos select-xcode generate-project ## Archive FocusMac (ARCHIVE_MODE=ci for unsigned gate)
	@if [[ "$${ARCHIVE_MODE:-}" == "ci" || "$${ARCHIVE_MODE:-}" == "unsigned" ]]; then \
		./Scripts/archive-macos-ci.sh; \
	else \
		xcodebuild -project Focus.xcodeproj -scheme FocusMac -archivePath build/Focus.xcarchive archive; \
	fi

verify-linux: assert-swift-toolchain docs-list lint assert-hardened-runtime assert-sparkle-info-plist ## Full Linux gate: toolchain, docs, lint, build, tests
	swift build
	swift test

verify-apple: require-macos log-apple-toolchain select-xcode ## Full Apple gate: build both, integration, smokes, archive
	@echo "verify-apple: generate, build both platforms, integration, smokes, archive"
	$(MAKE) generate-project
	$(MAKE) assert-generated-project
	$(MAKE) build-macos
	$(MAKE) build-ios
	$(MAKE) test-macos-integration
	$(MAKE) smoke-macos
	$(MAKE) smoke-ios
	$(MAKE) archive-macos ARCHIVE_MODE=ci

release-check: ## Tag/version/key checks (VERSION=x.y.z; no publish)
	@if [[ -z "$(VERSION)" ]]; then \
		echo "usage: make release-check VERSION=0.1.0" >&2; \
		exit 1; \
	fi
	./Scripts/release-check.sh "$(VERSION)"
