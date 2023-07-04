GODOT_EXECUTABLE := $(shell command -v godot3 2>/dev/null || command -v godot 2>/dev/null)
ifdef GODOT_EXECUTABLE
	GODOT_VERSION := $(shell $(GODOT_EXECUTABLE) --version 2>/dev/null | cut -d'.' -f1)
endif
CARGO := $(shell command -v cargo 2> /dev/null)
INSTALL_BIN = /usr/local/bin/
INSTALL_LIB = /usr/local/lib/
ICON_DIR = /usr/local/share/icons/hicolor/256x256/apps/
DESKTOP_DIR = /usr/local/share/applications/
BUILD_DIR = bin
DREAMDECK_LINUX = dreamdeck
DREAMDECK_WINDOWS = dreamdeck.exe
LIBDREAMDECK = libdreamdeck.so
RESOURCE_PATH = resources/general/
DREAMDECK_ICON = dreamdeck.png
DESKTOP_FILE = dreamdeck.desktop

.PHONY: all windows linux _check-godot _check-godot-version _build-linux _build-windows rust clean rust-clean install uninstall

all:
	$(MAKE) rust
	$(MAKE) _build-linux
	$(MAKE) _build-windows

windows:
	$(MAKE) rust
	$(MAKE) _build-windows

linux:
	$(MAKE) rust
	$(MAKE) _build-linux

_check-godot:
ifndef GODOT_EXECUTABLE
	$(error "Godot executable not found. Please make sure Godot3 is installed and in your system PATH.")
endif
	@$(MAKE) _check-godot-version

_check-godot-version:
ifneq "$(GODOT_VERSION)" "3"
	$(error "Found Godot version: $(GODOT_VERSION), but a version starting with 3 is required.")
endif

_build-linux: _check-godot
	@$(GODOT_EXECUTABLE) --export --no-window "Linux/X11"

_build-windows: _check-godot
	@$(GODOT_EXECUTABLE) --export --no-window "Windows Desktop"

rust:
ifndef CARGO
	$(error "Cargo not installed, rust is required")
endif
	cd rust && cargo build --release

clean: rust-clean
	rm -f $(BUILD_DIR)/$(DREAMDECK_LINUX)
	rm -f $(BUILD_DIR)/$(DREAMDECK_WINDOWS)
	rm -f $(BUILD_DIR)/$(LIBDREAMDECK)

rust-clean:
ifdef CARGO
	cd rust && cargo clean
endif

install:
	install -D bin/$(DREAMDECK_LINUX) $(INSTALL_BIN)$(DREAMDECK_LINUX)
	install -D bin/$(LIBDREAMDECK) $(INSTALL_LIB)$(LIBDREAMDECK)
	install -D $(RESOURCE_PATH)$(DREAMDECK_ICON) $(ICON_DIR)$(DREAMDECK_ICON)
	install -D $(RESOURCE_PATH)$(DESKTOP_FILE) $(DESKTOP_DIR)$(DESKTOP_FILE)

uninstall:
	rm -f $(INSTALL_BIN)$(DREAMDECK_LINUX)
	rm -f $(INSTALL_LIB)$(LIBDREAMDECK)
	rm -f $(ICON_DIR)$(DREAMDECK_ICON)
	rm -f $(DESKTOP_DIR)$(DESKTOP_FILE)
