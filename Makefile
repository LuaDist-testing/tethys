MODULE = tethys
VERSION = 2.0.3

INSTALL_PREFIX=/opt/tethys2
CONFIG_PREFIX=/etc/tethys2

default:
	cd extras; make

install: default
	install -d $(CONFIG_PREFIX)
	install -d $(INSTALL_PREFIX)
	cp -r bin docs tethys2 extras README changelog.txt COPYING $(INSTALL_PREFIX)
	cp config/*.config.lua $(CONFIG_PREFIX)
	sed -i "s@SELFCONTAINED=\"\"@SELFCONTAINED=\"$(INSTALL_PREFIX)\"@" $(INSTALL_PREFIX)/bin/tethys2-*
	sed -i "s@tethys = \"/opt/tethys2/\"@tethys = \"$(INSTALL_PREFIX)\"@" $(CONFIG_PREFIX)/smtp.config.lua

clean:
	find . -name '*~' -exec rm {} \;
	rm -rf dist/$(MODULE)-$(VERSION)
	if test -d extras; then if test -f extras/clean_all.sh; then cd extras; make clean; fi; fi

setup:
	scripts-helper/make-rockspec.sh $(MODULE)-$(VERSION)-1.rockspec

package: clean setup
	mkdir -p dist/$(MODULE)-$(VERSION)
	mkdir -p dist/$(MODULE)-$(VERSION)/config
	mkdir -p dist/$(MODULE)-$(VERSION)/extras
	echo "" > dist/$(MODULE)-$(VERSION)/extras/Makefile
	cp -r bin docs tethys2 rocks README changelog.txt COPYING Makefile dist/$(MODULE)-$(VERSION)
	cp config/*.config.lua dist/$(MODULE)-$(VERSION)/config/
	rm dist/$(MODULE)-$(VERSION)/config/test*
	find dist/$(MODULE)-$(VERSION) -name .svn | xargs rm -rf
	find dist/$(MODULE)-$(VERSION) -name private | xargs rm -rf
	tar cvzf $(MODULE)-$(VERSION).tar.gz -C dist $(MODULE)-$(VERSION)
	rm -rf dist/$(MODULE)-$(VERSION)

package-full: clean setup
	mkdir -p dist/$(MODULE)-$(VERSION)
	mkdir -p dist/$(MODULE)-$(VERSION)/config
	cp -r bin docs tethys2 rocks README extras changelog.txt COPYING Makefile dist/$(MODULE)-$(VERSION)
	cp config/*.config.lua dist/$(MODULE)-$(VERSION)/config/
	rm dist/$(MODULE)-$(VERSION)/config/test*
	find dist/$(MODULE)-$(VERSION) -name .svn | xargs rm -rf
	find dist/$(MODULE)-$(VERSION) -name private | xargs rm -rf
	tar cvzf $(MODULE)-$(VERSION)-full.tar.gz -C dist $(MODULE)-$(VERSION)
	rm -rf dist/$(MODULE)-$(VERSION)
