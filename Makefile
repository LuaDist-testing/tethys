MODULE = tethys
VERSION = 2.0.0

default: setup

setup:
	scripts-helper/make-rockspec.sh $(MODULE)-$(VERSION)-1.rockspec

clean:
	find . -name '*~' -exec rm {} \;
	rm -rf dist/$(MODULE)-$(VERSION)

package: clean setup
	mkdir -p dist/$(MODULE)-$(VERSION)
	mkdir -p dist/$(MODULE)-$(VERSION)/config
	cp -r bin docs tethys2 rocks COPYING Makefile dist/$(MODULE)-$(VERSION)
	cp config/*.config.lua dist/$(MODULE)-$(VERSION)/config/
	find dist/$(MODULE)-$(VERSION) -name .svn | xargs rm -rf
	find dist/$(MODULE)-$(VERSION) -name private | xargs rm -rf
	tar cvzf $(MODULE)-$(VERSION).tar.gz -C dist $(MODULE)-$(VERSION)
	rm -rf dist/$(MODULE)-$(VERSION)
