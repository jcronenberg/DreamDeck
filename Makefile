GODOT_EXECUTABLE := $(shell command -v godot3 2>/dev/null || command -v godot 2>/dev/null)
ifdef GODOT_EXECUTABLE
	GODOT_VERSION := $(shell $(GODOT_EXECUTABLE) --version 2>/dev/null | cut -d'.' -f1)
endif
CARGO := $(shell command -v cargo 2> /dev/null)

.PHONY: all windows linux _check-godot _check-godot-version _build-linux _build-windows rust-build clean rust-clean

all:
	$(MAKE) rust-build
	$(MAKE) _build-linux
	$(MAKE) _build-windows

windows:
	$(MAKE) rust-build
	$(MAKE) _build-windows

linux:
	$(MAKE) rust-build
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

rust-build:
ifndef CARGO
	$(error "Cargo not installed, rust is required")
endif
	cd rust && cargo build --release

clean: rust-clean
	rm -rf bin/*

rust-clean:
ifdef CARGO
	cd rust && cargo clean
endif
