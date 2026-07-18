SHELL := /bin/bash
.DEFAULT_GOAL := help

SWIFT_FORMAT_PATHS := Sources Tests CLI Apps
VERSION ?=
IOS_DESTINATION ?=

.PHONY: help docs-list format lint check-skills generate-project \
	assert-swift-toolchain assert-generated-project \
	test-linux test-session test-persistence test-control test-cli test-platform-gating \
	log-apple-toolchain select-xcode select-ios-simulator \
	build-macos build-ios test-macos-integration smoke-macos smoke-ios archive-macos \
	verify-linux verify-apple release-check require-macos

help:
	@echo "Focus Makefile targets:"
	@echo "  docs-list format lint check-skills generate-project"
	@echo "  assert-swift-toolchain assert-generated-project"
	@echo "  test-linux test-session test-persistence test-control test-cli test-platform-gating"
	@echo "  log-apple-toolchain select-xcode select-ios-simulator"
	@echo "  build-macos build-ios test-macos-integration smoke-macos smoke-ios archive-macos"
	@echo "  verify-linux verify-apple release-check"

docs-list:
	node Scripts/docs-list.mjs

format:
	swift format --in-place --recursive $(SWIFT_FORMAT_PATHS)

lint:
	swift format lint --recursive $(SWIFT_FORMAT_PATHS)
	swift Scripts/check-concurrency-safety.swift

check-skills:
	./Scripts/check-skills

assert-swift-toolchain:
	./Scripts/assert-swift-toolchain.sh

generate-project:
	swift run --package-path tools/projectgen xcodegen generate --spec project.yml --project .

assert-generated-project:
	./Scripts/assert-generated-project.sh

test-linux:
	swift test

test-session:
	swift test --filter FocusSessionTests

test-persistence:
	swift test --filter FocusPersistenceIntegrationTests

test-control:
	swift test --filter FocusControlTests

test-cli:
	swift test --filter FocusCLIIntegrationTests

test-platform-gating:
	swift test --filter FocusPlatformGatingTests

require-macos:
	@if [[ "$$(uname -s)" != "Darwin" ]]; then \
		echo "error: this target requires macOS with Xcode 26.6" >&2; \
		exit 1; \
	fi

log-apple-toolchain: require-macos
	./Scripts/log-apple-toolchain.sh

select-xcode: require-macos
	./Scripts/select-xcode.sh

select-ios-simulator: require-macos
	./Scripts/select-ios-simulator.sh

build-macos: require-macos select-xcode generate-project assert-generated-project
	xcodebuild -project Focus.xcodeproj -scheme FocusMac -destination "generic/platform=macOS" build

build-ios: require-macos select-xcode generate-project assert-generated-project
	xcodebuild -project Focus.xcodeproj -scheme FocusIOS -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build

test-macos-integration: require-macos select-xcode generate-project
	xcodebuild -project Focus.xcodeproj -scheme FocusMacIntegrationTests -destination "platform=macOS" test

smoke-macos: require-macos select-xcode generate-project
	xcodebuild -project Focus.xcodeproj -scheme FocusMacUITests -destination "platform=macOS" test

smoke-ios: require-macos select-xcode generate-project
	@dest="$(IOS_DESTINATION)"; \
	if [[ -z "$$dest" ]]; then \
		dest="$$(./Scripts/select-ios-simulator.sh)"; \
	fi; \
	echo "smoke-ios: destination=$$dest"; \
	xcodebuild -project Focus.xcodeproj -scheme FocusIOSUITests -destination "$$dest" CODE_SIGNING_ALLOWED=NO test

archive-macos: require-macos select-xcode generate-project
	@if [[ "$${ARCHIVE_MODE:-}" == "ci" || "$${ARCHIVE_MODE:-}" == "unsigned" ]]; then \
		./Scripts/archive-macos-ci.sh; \
	else \
		xcodebuild -project Focus.xcodeproj -scheme FocusMac -archivePath build/Focus.xcarchive archive; \
	fi

verify-linux: assert-swift-toolchain docs-list lint check-skills
	swift build
	swift test

verify-apple: require-macos log-apple-toolchain select-xcode
	@echo "verify-apple: generate, build both platforms, integration, smokes, archive"
	$(MAKE) generate-project
	$(MAKE) assert-generated-project
	$(MAKE) build-macos
	$(MAKE) build-ios
	$(MAKE) test-macos-integration
	$(MAKE) smoke-macos
	$(MAKE) smoke-ios
	$(MAKE) archive-macos ARCHIVE_MODE=ci

release-check:
	@if [[ -z "$(VERSION)" ]]; then \
		echo "usage: make release-check VERSION=0.1.0" >&2; \
		exit 1; \
	fi
	./Scripts/release-check.sh "$(VERSION)"
