GODOT_EXECUTABLE := $(shell command -v godot4 2>/dev/null || command -v godot 2>/dev/null)
ifdef GODOT_EXECUTABLE
	GODOT_VERSION := $(shell $(GODOT_EXECUTABLE) --version 2>/dev/null | cut -d'.' -f1)
endif
CARGO := $(shell command -v cargo 2> /dev/null)
RUST_DIRS ?= plugins/ssh/rust/ plugins/touch/rust/

DESTDIR ?=
PREFIX ?= /usr/local
CARGO_FLAGS ?=

bindir ?= $(PREFIX)/bin/
# TODO change to lib64 once that is supported by godot
libdir ?= $(PREFIX)/lib/
icondir ?= $(PREFIX)/share/icons/hicolor/256x256/apps/
applicationsdir ?= $(PREFIX)/share/applications/
builddir = bin
appname = dreamdeck
linuxbinary = dreamdeck
windowsbinary = dreamdeck.exe
touchlib = libdreamdeck_touch.so
sshlib = libdreamdeck_ssh.so
iconfile = dreamdeck.png
desktopfile = dreamdeck.desktop

define NO_CARGO_MESSAGE
	$(info INFO: No cargo found, building without rust)
endef

.PHONY: all windows linux _check-godot _check-godot-version _build-linux _build-windows rust clean rust-clean install uninstall linux-dist _godot-import install-flatpak

all:
ifdef CARGO
	$(MAKE) rust
	$(MAKE) _build-linux
	$(MAKE) _build-windows
else
	$(NO_CARGO_MESSAGE)
	$(MAKE) _build-linux-rustless
	$(MAKE) _build-windows-rustless
endif


windows:
ifdef CARGO
	$(MAKE) rust
	$(MAKE) _build-windows
else
	$(NO_CARGO_MESSAGE)
	$(MAKE) _build-windows-rustless
endif

linux:
ifdef CARGO
	$(MAKE) rust
	$(MAKE) _build-linux
else
	$(NO_CARGO_MESSAGE)
	$(MAKE) _build-linux-rustless
endif

linux-debug:
	$(MAKE) rust-debug
	$(MAKE) _build-linux-debug

linux-rustless:
	$(MAKE) _build-linux-rustless

windows-rustless:
	$(MAKE) _build-windows-rustless

linux-dist:
	$(MAKE) linux
	tar zcvf $(builddir)/$(appname).tar.gz -C $(builddir) $(linuxbinary) $(sshlib) $(touchlib)

_check-godot:
ifndef GODOT_EXECUTABLE
	$(error "Godot executable not found. Please make sure Godot4 is installed and in your system PATH.")
endif
	@$(MAKE) _check-godot-version

_check-godot-version:
ifneq "$(GODOT_VERSION)" "4"
	$(error "Found Godot version: $(GODOT_VERSION), but a version starting with 4 is required.")
endif

_godot-import:
	@$(GODOT_EXECUTABLE) --headless --import || true

_build-linux: _check-godot
	$(MAKE) _godot-import
	@$(GODOT_EXECUTABLE) --headless --export-release "Linux"

_build-linux-debug: _check-godot
	$(MAKE) _godot-import
	@$(GODOT_EXECUTABLE) --headless --export-release "Linux"

_build-windows: _check-godot
	$(MAKE) _godot-import
	@$(GODOT_EXECUTABLE) --headless --export-release "Windows Desktop"

_build-linux-rustless: _check-godot
	$(MAKE) _godot-import
	@$(GODOT_EXECUTABLE) --headless --export-release "Linux without rust"

_build-windows-rustless: _check-godot
	$(MAKE) _godot-import
	@$(GODOT_EXECUTABLE) --headless --export-release "Windows Desktop without rust"

rust:
ifndef CARGO
	$(error "Cargo not installed, rust is required")
endif
	for dir in $(RUST_DIRS); do cargo build --manifest-path $${dir}/Cargo.toml --release $(CARGO_FLAGS); done

rust-debug:
ifndef CARGO
	$(error "Cargo not installed, rust is required")
endif
	for dir in $(RUST_DIRS); do cargo build --manifest-path $${dir}/Cargo.toml $(CARGO_FLAGS); done

clean: rust-clean
	rm -f $(builddir)/$(linuxbinary)
	rm -f $(builddir)/$(windowsbinary)
	rm -f $(builddir)/$(sshlib)
	rm -f $(builddir)/$(touchlib)
	rm -f $(builddir)/$(appname).tar.gz

rust-clean:
ifdef CARGO
	for dir in $(RUST_DIRS); do cargo clean --manifest-path $${dir}/Cargo.toml; done
endif

install:
	install -Dm 755 $(builddir)/$(linuxbinary) $(DESTDIR)$(bindir)$(linuxbinary)
ifneq ($(wildcard $(builddir)/$(sshlib)),)
	install -Dm 755 $(builddir)/$(sshlib) $(DESTDIR)$(libdir)$(sshlib)
endif
ifneq ($(wildcard bin/$(touchlib)),)
	install -Dm 755 $(builddir)/$(touchlib) $(DESTDIR)$(libdir)$(touchlib)
endif
	install -Dm 644 resources/icons/$(iconfile) $(DESTDIR)$(icondir)$(iconfile)
	mkdir -p $(DESTDIR)$(applicationsdir)
	sed "s|@PREFIX@|$(PREFIX)|g" dist/$(desktopfile).in > $(DESTDIR)$(applicationsdir)$(desktopfile)

install-flatpak:
	install -Dm 755 $(builddir)/$(linuxbinary) $(DESTDIR)$(bindir)$(linuxbinary)
	install -Dm 755 plugins/ssh/rust/target/release/$(sshlib) $(DESTDIR)$(libdir)$(sshlib)
	install -Dm 755 plugins/touch/rust/target/release/$(touchlib) $(DESTDIR)$(libdir)$(touchlib)
	install -Dm 644 resources/icons/$(iconfile) $(DESTDIR)$(icondir)$(iconfile)
	mkdir -p $(DESTDIR)$(applicationsdir)
	sed "s|@PREFIX@|$(PREFIX)|g" dist/$(desktopfile).in > $(DESTDIR)$(applicationsdir)dev.jcronenberg.DreamDeck.desktop
	install -Dm 644 dreamdeck.pck $(DESTDIR)$(bindir)dreamdeck.pck

uninstall:
	rm -f $(DESTDIR)$(bindir)$(linuxbinary)
	rm -f $(DESTDIR)$(libdir)$(sshlib)
	rm -f $(DESTDIR)$(libdir)$(touchlib)
	rm -f $(DESTDIR)$(icondir)$(iconfile)
	rm -f $(DESTDIR)$(applicationsdir)$(desktopfile)
