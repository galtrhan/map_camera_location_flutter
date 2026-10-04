.PHONY: help get analyze test clean \
	build-apk run-debug run-release run run-attach _run-emulator \
	emulator-setup emulator-list emulator-start emulator-start-phone \
	emulator-start-tablet7 emulator-start-tablet10 emulator-stop \
	emulator-status emulator-wait \
	version-bump

# Android emulator AVD: Test (phone), Tablet7, Tablet10
AVD ?= Test
FLUTTER_RUN_FLAGS ?=

# Java 21 path (required for building)
JAVA_HOME=/usr/lib/jvm/java-21-openjdk
export JAVA_HOME

# Prefer a writable user SDK when present (needed for platform installs).
# Fall back to the system SDK for emulators and shared tools.
ifeq ($(wildcard $(HOME)/Android/Sdk/platforms),)
  ANDROID_SDK_ROOT ?= /opt/android-sdk
else
  ANDROID_SDK_ROOT ?= $(HOME)/Android/Sdk
endif
export ANDROID_SDK_ROOT
# Emulator binaries may still live under /opt/android-sdk.
ANDROID_EMULATOR_SDK ?= /opt/android-sdk
export ANDROID_EMULATOR_SDK

# FVM Flutter path (project-local SDK via `fvm use`)
FVM_FLUTTER := $(CURDIR)/.fvm/flutter_sdk/bin
export PATH := $(FVM_FLUTTER):$(PATH)

FLUTTER_CMD = JAVA_HOME=$(JAVA_HOME) ANDROID_SDK_ROOT=$(ANDROID_SDK_ROOT) flutter

help:
	@echo "map_camera_flutter - Available commands:"
	@echo ""
	@echo "PACKAGE:"
	@echo "  make get                Get deps for package and example"
	@echo "  make analyze            Analyze package and example"
	@echo "  make test               Run package tests"
	@echo "  make clean              Clean package and example builds"
	@echo "  make version-bump       Bump patch version in pubspec.yaml"
	@echo ""
	@echo "EXAMPLE APP:"
	@echo "  make build-apk          Build example release APK"
	@echo "  make run                Install+launch on emulator, then exit"
	@echo "  make run-attach         Interactive flutter run (hot reload)"
	@echo "  make run-debug          Interactive run on a connected device"
	@echo "  make run-release        Interactive release run on a device"
	@echo ""
	@echo "EMULATOR:"
	@echo "  make emulator-setup     Create phone + tablet AVDs (one-time)"
	@echo "  make emulator-list      List available AVDs"
	@echo "  make emulator-start     Start emulator (default: Test phone)"
	@echo "  make emulator-wait      Wait until emulator boot is finished"
	@echo "  make emulator-start AVD=Tablet7   Start 7\" tablet"
	@echo "  make emulator-start AVD=Tablet10  Start 10\" tablet"
	@echo "  make emulator-start-phone|tablet7|tablet10  Shortcuts"
	@echo "  make emulator-stop      Stop the Android emulator"
	@echo "  make emulator-status    Check emulator status"
	@echo ""
	@echo "Tip: use make run inside Cursor. Use make run-attach in an"
	@echo "external terminal when you need hot reload."

get:
	@echo "Getting package dependencies..."
	flutter pub get
	@echo "Getting example dependencies..."
	cd example && flutter pub get
	@echo "Dependencies updated"

analyze:
	@echo "Analyzing package..."
	flutter analyze
	@echo "Analyzing example..."
	cd example && flutter analyze

test:
	@echo "Running package tests..."
	flutter test

clean:
	@echo "Cleaning package..."
	flutter clean
	@echo "Cleaning example..."
	cd example && flutter clean
	@echo "Clean complete"

build-apk: get
	@echo "Building example APK release..."
	cd example && $(FLUTTER_CMD) build apk --release
	@echo "APK ready: example/build/app/outputs/flutter-apk/app-release.apk"

run-debug:
	@echo "Running example (debug, interactive)..."
	cd example && $(FLUTTER_CMD) run

run-release:
	@echo "Running example (release, interactive)..."
	cd example && $(FLUTTER_CMD) run --release

# Default: build/install/launch, then exit. Does not keep a Flutter resident
# process attached (that session freezes Cursor when paired with an emulator).
run: emulator-wait
	@$(MAKE) _run-emulator FLUTTER_RUN_FLAGS=--no-resident

# Interactive hot-reload session. Prefer an external terminal, not Cursor.
run-attach: emulator-wait
	@echo "Prefer an external terminal for hot reload."
	@$(MAKE) _run-emulator FLUTTER_RUN_FLAGS=

_run-emulator:
	@EMULATOR=$$(ANDROID_SDK_ROOT=$(ANDROID_EMULATOR_SDK) adb devices | awk '/^emulator-/{print $$1; exit}'); \
	if [ -z "$$EMULATOR" ]; then \
		echo "No emulator running. Start one with: make emulator-start"; \
		exit 1; \
	fi; \
	echo "Using device $$EMULATOR"; \
	cd example && $(FLUTTER_CMD) run -d $$EMULATOR $(FLUTTER_RUN_FLAGS)

emulator-setup:
	@ANDROID_SDK_ROOT=$(ANDROID_EMULATOR_SDK) scripts/setup_emulators.sh

emulator-list:
	@echo "Configured AVDs (start with: make emulator-start AVD=<name>):"
	@echo "  Test      Pixel 6 phone"
	@echo "  Tablet7   Nexus 7 (7\" tablet)"
	@echo "  Tablet10  Pixel Tablet (10\" tablet)"
	@echo ""
	@ANDROID_SDK_ROOT=$(ANDROID_EMULATOR_SDK) $(ANDROID_EMULATOR_SDK)/emulator/emulator -list-avds 2>/dev/null || \
		echo "  (none installed — run make emulator-setup)"

emulator-start:
	@ANDROID_SDK_ROOT=$(ANDROID_EMULATOR_SDK) scripts/emulator_start.sh $(AVD)

emulator-wait:
	@ANDROID_SDK_ROOT=$(ANDROID_EMULATOR_SDK) scripts/emulator_wait.sh

emulator-start-phone:
	@$(MAKE) emulator-start AVD=Test

emulator-start-tablet7:
	@$(MAKE) emulator-start AVD=Tablet7

emulator-start-tablet10:
	@$(MAKE) emulator-start AVD=Tablet10

emulator-stop:
	@echo "Stopping Android emulator..."
	ANDROID_SDK_ROOT=$(ANDROID_EMULATOR_SDK) adb emu kill
	@echo "Emulator stopped"

emulator-status:
	@echo "Checking emulator status..."
	ANDROID_SDK_ROOT=$(ANDROID_EMULATOR_SDK) adb devices

version-bump:
	@echo "Bumping version in pubspec.yaml..."
	@scripts/bump_version.sh
