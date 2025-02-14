GODOT_EXECUTABLE := $(shell command -v godot4 2>/dev/null || command -v godot 2>/dev/null)
ifdef GODOT_EXECUTABLE
	GODOT_VERSION := $(shell $(GODOT_EXECUTABLE) --version 2>/dev/null | cut -d'.' -f1)
endif
CARGO := $(shell command -v cargo 2> /dev/null)
TOUCH_MANIFEST ?= plugins/touch/rust/Cargo.toml
SSH_MANIFEST ?= plugins/ssh/rust/Cargo.toml

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

.PHONY: all windows linux _check-godot _check-godot-version godot-build-linux godot-build-windows rust clean rust-clean install uninstall linux-dist godot-import install-flatpak

all:
ifdef CARGO
	$(MAKE) rust
	$(MAKE) build-linux
	$(MAKE) build-windows
else
	$(NO_CARGO_MESSAGE)
	$(MAKE) godot-build-linux-rustless
	$(MAKE) godot-build-windows-rustless
endif


windows:
ifdef CARGO
	$(MAKE) rust-ssh-release
	$(MAKE) godot-build-windows
else
	$(NO_CARGO_MESSAGE)
	$(MAKE) godot-build-windows-rustless
endif

linux:
ifdef CARGO
	$(MAKE) rust
	$(MAKE) godot-build-linux
else
	$(NO_CARGO_MESSAGE)
	$(MAKE) godot-build-linux-rustless
endif

linux-debug:
	$(MAKE) rust-debug
	$(MAKE) godot-build-linux-debug

linux-rustless:
	$(MAKE) godot-build-linux-rustless

windows-rustless:
	$(MAKE) godot-build-windows-rustless

linux-dist:
	$(MAKE) linux
	tar zcvf $(builddir)/$(appname).tar.gz -C $(builddir) $(linuxbinary) $(sshlib) $(touchlib)

godot-import:
	@$(GODOT_EXECUTABLE) --headless --import || true

godot-build-linux: _check-godot
	$(MAKE) godot-import
	@$(GODOT_EXECUTABLE) --headless --export-release "Linux"

godot-build-linux-debug: _check-godot
	$(MAKE) godot-import
	@$(GODOT_EXECUTABLE) --headless --export-release "Linux"

godot-build-windows: _check-godot
	$(MAKE) godot-import
	@$(GODOT_EXECUTABLE) --headless --export-release "Windows Desktop"

godot-build-linux-rustless: _check-godot
	$(MAKE) godot-import
	@$(GODOT_EXECUTABLE) --headless --export-release "Linux without rust"

godot-build-windows-rustless: _check-godot
	$(MAKE) godot-import
	@$(GODOT_EXECUTABLE) --headless --export-release "Windows Desktop without rust"

rust:
ifndef CARGO
	$(error "Cargo not installed, rust is required")
endif
	$(MAKE) rust-touch-release
	$(MAKE) rust-ssh-release

rust-debug:
ifndef CARGO
	$(error "Cargo not installed, rust is required")
endif
	$(MAKE) rust-touch-debug
	$(MAKE) rust-ssh-debug

clean: rust-clean
	rm -f $(builddir)/$(linuxbinary)
	rm -f $(builddir)/$(windowsbinary)
	rm -f $(builddir)/$(sshlib)
	rm -f $(builddir)/$(touchlib)
	rm -f $(builddir)/$(appname).tar.gz

rust-clean:
	for manifest in $(TOUCH_MANIFEST) $(SSH_MANIFEST); do $(CARGO) clean --manifest-path $${manifest}; done

rust-touch-release:
	@$(CARGO) build --manifest-path $(TOUCH_MANIFEST) --release $(CARGO_FLAGS)

rust-touch-debug:
	@$(CARGO) build --manifest-path $(TOUCH_MANIFEST) $(CARGO_FLAGS)

rust-ssh-release:
	@$(CARGO) build --manifest-path $(SSH_MANIFEST) --release $(CARGO_FLAGS)

rust-ssh-debug:
	@$(CARGO) build --manifest-path $(SSH_MANIFEST) $(CARGO_FLAGS)

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

_check-godot:
ifndef GODOT_EXECUTABLE
	$(error "Godot executable not found. Please make sure Godot4 is installed and in your system PATH.")
endif
	@$(MAKE) _check-godot-version

_check-godot-version:
ifneq "$(GODOT_VERSION)" "4"
	$(error "Found Godot version: $(GODOT_VERSION), but a version starting with 4 is required.")
endif
