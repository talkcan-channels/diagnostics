PACKAGE := talkcan-channel.zip
LUA_SOURCES := $(shell find lua -type f -name '*.lua' -print | LC_ALL=C sort)

.PHONY: package clean

package: $(PACKAGE)

$(PACKAGE): manifest.json $(LUA_SOURCES)
	rm -f $@
	zip -X -0 $@ manifest.json $(LUA_SOURCES)

clean:
	rm -f $(PACKAGE)
