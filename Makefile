SHELL := /bin/bash
.DEFAULT_GOAL := help

SWIFT_FORMAT_PATHS := Sources Tests CLI Apps
XCODE := /Applications/Xcode_26.6.app/Contents/Developer
VERSION ?=

.PHONY: help docs-list format lint check-skills generate-project \
	test-linux test-session test-persistence test-control test-cli test-platform-gating \
	build-macos build-ios test-macos-integration smoke-macos smoke-ios archive-macos \
	verify-linux verify-apple release-check require-macos

help:
	@echo "Focus Makefile targets:"
	@echo "  docs-list format lint check-skills generate-project"
	@echo "  test-linux test-session test-persistence test-control test-cli test-platform-gating"
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

generate-project:
	swift run --package-path tools/projectgen xcodegen generate --spec project.yml --project .

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
	@if [[ ! -d "$(XCODE)" ]]; then \
		echo "error: expected Xcode at $(XCODE)" >&2; \
		exit 1; \
	fi

build-macos: require-macos generate-project
	sudo xcode-select -s "$(XCODE)"
	xcodebuild -project Focus.xcodeproj -scheme FocusMac -destination "generic/platform=macOS" build

build-ios: require-macos generate-project
	sudo xcode-select -s "$(XCODE)"
	xcodebuild -project Focus.xcodeproj -scheme FocusIOS -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build

test-macos-integration: require-macos generate-project
	sudo xcode-select -s "$(XCODE)"
	xcodebuild -project Focus.xcodeproj -scheme FocusMacIntegrationTests -destination "platform=macOS" test

smoke-macos: require-macos generate-project
	sudo xcode-select -s "$(XCODE)"
	xcodebuild -project Focus.xcodeproj -scheme FocusMacUITests -destination "platform=macOS" test

smoke-ios: require-macos generate-project
	sudo xcode-select -s "$(XCODE)"
	xcodebuild -project Focus.xcodeproj -scheme FocusIOSUITests -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO test

archive-macos: require-macos generate-project
	sudo xcode-select -s "$(XCODE)"
	xcodebuild -project Focus.xcodeproj -scheme FocusMac -archivePath build/Focus.xcarchive archive

verify-linux: docs-list lint check-skills
	swift build
	swift test

verify-apple: require-macos
	@echo "verify-apple: select Xcode, generate, build both platforms, integration, smokes, archive"
	xcode-select -p
	xcodebuild -version
	xcodebuild -showsdks
	$(MAKE) generate-project
	$(MAKE) build-macos
	$(MAKE) build-ios
	$(MAKE) test-macos-integration
	$(MAKE) smoke-macos
	$(MAKE) smoke-ios
	$(MAKE) archive-macos

release-check:
	@if [[ -z "$(VERSION)" ]]; then \
		echo "usage: make release-check VERSION=0.1.0" >&2; \
		exit 1; \
	fi
	@echo "release-check: validating foundation presence for $(VERSION)"
	@test -f LICENSE
	@test -f CHANGELOG.md
	@grep -Fq "$(VERSION)" CHANGELOG.md || (echo "error: $(VERSION) not mentioned in CHANGELOG.md" >&2; exit 1)
	@test -f THIRD_PARTY_NOTICES.md
	@test -f project.yml
	@test -f Package.swift
	@echo "release-check: ok (structural; secrets/feed hosting not required yet)"
