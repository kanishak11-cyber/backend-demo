BREW_PREFIX := $(shell brew --prefix 2>/dev/null || echo /usr/local)
# Homebrew's libpq is keg-only, so point pkg-config at it when present.
LIBPQ_PC := $(shell brew --prefix libpq 2>/dev/null)/lib/pkgconfig
PKG_CONFIG := PKG_CONFIG_PATH=$(LIBPQ_PC):$$PKG_CONFIG_PATH pkg-config

CXXFLAGS ?= -std=c++17 -O2 -Wall -Wextra
CPPFLAGS += -isystem $(BREW_PREFIX)/include $(shell $(PKG_CONFIG) --cflags libpq hiredis)
LDLIBS += $(shell $(PKG_CONFIG) --libs libpq hiredis) -pthread

server: main.cpp
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) $< -o $@ $(LDLIBS)

run: server
	./server

clean:
	rm -f server

.PHONY: run clean
