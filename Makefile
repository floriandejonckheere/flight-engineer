APP_NAME := Flight Engineer
DERIVED_DATA := build/DerivedData
PRODUCT := $(DERIVED_DATA)/Build/Products/Release/$(APP_NAME).app
INSTALL_DIR ?= /Applications
VERSION ?= $(shell git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')
ARCHIVE := build/FlightEngineer-$(VERSION).zip

XCODEBUILD_FLAGS := $(if $(VERSION),MARKETING_VERSION=$(VERSION))

.PHONY: all generate build install package test clean

all: build

generate:
	xcodegen generate

build: generate
	xcodebuild -project FlightEngineer.xcodeproj -scheme FlightEngineer \
		-configuration Release -derivedDataPath $(DERIVED_DATA) \
		ONLY_ACTIVE_ARCH=NO $(XCODEBUILD_FLAGS) build

install: build
	pkill -x "$(APP_NAME)" || true
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	cp -R "$(PRODUCT)" "$(INSTALL_DIR)/"
	open "$(INSTALL_DIR)/$(APP_NAME).app"

package: build
	ditto -c -k --keepParent "$(PRODUCT)" "$(ARCHIVE)"
	shasum -a 256 "$(ARCHIVE)"

test:
	swift test --package-path Packages/FlightEngineerKit

clean:
	rm -rf build FlightEngineer.xcodeproj
