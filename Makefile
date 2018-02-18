PROG ?= otp
PREFIX ?= /usr
DESTDIR ?=
LIBDIR ?= $(PREFIX)/lib
SYSTEM_EXTENSION_DIR ?= $(LIBDIR)/password-store/extensions
MANDIR ?= $(PREFIX)/share/man

all:
	@echo "pass-$(PROG) is a shell script and does not need compilation, it can be simply executed."
	@echo ""
	@echo "To install it try \"make install\" instead."
	@echo
	@echo "To run pass $(PROG) one needs to have some tools installed on the system:"
	@echo "     password store"

install:
	@install -v -d "$(DESTDIR)$(MANDIR)/man1" && install -m 0644 -v pass-$(PROG).1 "$(DESTDIR)$(MANDIR)/man1/pass-$(PROG).1"
	@install -v -d "$(DESTDIR)$(SYSTEM_EXTENSION_DIR)/"
	@install -v -m0755 $(PROG).bash "$(DESTDIR)$(SYSTEM_EXTENSION_DIR)/$(PROG).bash"
	@echo
	@echo "pass-$(PROG) is installed succesfully"
	@echo

uninstall:
	@rm -vrf \
		"$(DESTDIR)$(SYSTEM_EXTENSION_DIR)/$(PROG).bash" \
		"$(DESTDIR)$(MANDIR)/man1/pass-$(PROG).1"

lint:
	shellcheck -s bash $(PROG).bash

doc: pass-$(PROG).1

pass-$(PROG).1: pass-$(PROG).1.md
	@echo "Building pass-$(PROG) documentation"
	@pandoc -s -f markdown -t man pass-$(PROG).1.md -o pass-$(PROG).1

.PHONY: install uninstall lint
