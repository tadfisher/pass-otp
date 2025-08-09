PROG ?= otp
PREFIX ?= /usr/local
DESTDIR ?=
LIBDIR ?= $(PREFIX)/lib
SYSTEM_EXTENSION_DIR ?= $(LIBDIR)/password-store/extensions
MANDIR ?= $(PREFIX)/man
BASHCOMPDIR ?= /etc/bash_completion.d

all:
	@echo "pass-$(PROG) is a shell script and does not need compilation, it can be simply executed."
	@echo ""
	@echo "To install it try \"make install\" instead."
	@echo
	@echo "To run pass $(PROG) one needs to have some tools installed on the system:"
	@echo "     password store"

install:
	install -d "$(DESTDIR)$(MANDIR)/man1" && install -m 0644 pass-$(PROG).1 "$(DESTDIR)$(MANDIR)/man1/pass-$(PROG).1"
	install -d "$(DESTDIR)$(SYSTEM_EXTENSION_DIR)/"
	install -m0755 $(PROG).bash "$(DESTDIR)$(SYSTEM_EXTENSION_DIR)/$(PROG).bash"
	install -d "$(DESTDIR)$(BASHCOMPDIR)/"
	install -m 644 pass-otp.bash.completion  "$(DESTDIR)$(BASHCOMPDIR)/pass-otp"
	@echo
	@echo "pass-$(PROG) is installed successfully"
	@echo

uninstall:
	rm -vrf \
		"$(DESTDIR)$(SYSTEM_EXTENSION_DIR)/$(PROG).bash" \
		"$(DESTDIR)$(MANDIR)/man1/pass-$(PROG).1" \
		"$(DESTDIR)$(BASHCOMPDIR)/pass-otp"

lint:
	shellcheck -s bash $(PROG).bash
	$(MAKE) -C test lint

test:
	$(MAKE) -C test all

check: lint test

.PHONY: install uninstall lint test check
