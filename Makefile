HS_DIRS := src app test
HS_FILES = $(shell find $(HS_DIRS) -name '*.hs')

.PHONY: build test check

build:
	cabal build all

test:
	cabal test all --test-show-details=direct

check:
	@if command -v fourmolu >/dev/null; then fourmolu --mode check $(HS_FILES); else echo "fourmolu not installed: skipping format check"; fi
	@if command -v hlint >/dev/null; then hlint $(HS_DIRS); else echo "hlint not installed: skipping lint"; fi
