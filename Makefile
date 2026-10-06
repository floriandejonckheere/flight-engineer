APP_NAME := Flight Engineer
DERIVED_DATA := build/DerivedData
PRODUCT := $(DERIVED_DATA)/Build/Products/Release/$(APP_NAME).app
INSTALL_DIR ?= /Applications

.PHONY: all generate build install test clean

all: build

generate:
	xcodegen generate

build: generate
	xcodebuild -project FlightEngineer.xcodeproj -scheme FlightEngineer \
		-configuration Release -derivedDataPath $(DERIVED_DATA) build

install: build
	pkill -x "$(APP_NAME)" || true
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	cp -R "$(PRODUCT)" "$(INSTALL_DIR)/"
	open "$(INSTALL_DIR)/$(APP_NAME).app"

test:
	swift test --package-path Packages/FlightEngineerKit

clean:
	rm -rf build FlightEngineer.xcodeproj
