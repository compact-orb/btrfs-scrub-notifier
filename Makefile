PREFIX ?= /usr/local
SYSCONFDIR ?= /etc
SYSTEMDDIR ?= /etc/systemd/system

.PHONY: install uninstall

install:
	install -d $(DESTDIR)$(PREFIX)/bin/
	install -m 755 btrfs-scrub-notifier.sh $(DESTDIR)$(PREFIX)/bin/btrfs-scrub-notifier.sh
	install -d $(DESTDIR)$(SYSCONFDIR)/
	@if [ ! -f $(DESTDIR)$(SYSCONFDIR)/btrfs-scrub-notifier.conf ]; then \
		install -m 644 btrfs-scrub-notifier.conf $(DESTDIR)$(SYSCONFDIR)/btrfs-scrub-notifier.conf; \
	else \
		echo "Skipping btrfs-scrub-notifier.conf installation as it already exists."; \
	fi
	install -d $(DESTDIR)$(SYSTEMDDIR)/
	install -m 644 btrfs-scrub-notifier@.service $(DESTDIR)$(SYSTEMDDIR)/
	install -m 644 btrfs-scrub-notifier@.timer $(DESTDIR)$(SYSTEMDDIR)/
	@echo "Installation complete."
	@echo "Review configuration in $(DESTDIR)$(SYSCONFDIR)/btrfs-scrub-notifier.conf"
	@echo "Run 'systemctl daemon-reload' to load the new systemd units."

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/btrfs-scrub-notifier.sh
	rm -f $(DESTDIR)$(SYSCONFDIR)/btrfs-scrub-notifier.conf
	rm -f $(DESTDIR)$(SYSTEMDDIR)/btrfs-scrub-notifier@.service
	rm -f $(DESTDIR)$(SYSTEMDDIR)/btrfs-scrub-notifier@.timer
	@echo "Uninstallation complete."
