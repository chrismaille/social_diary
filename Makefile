# Social Diary's checks. `make check` is what the CI runs; `make lint` runs
# the pre-commit hooks themselves, over every file git tracks *and* the new
# ones not yet staged (which `pre-commit run --all-files` skips).

LUAJIT ?= luajit
LUACHECK ?= luacheck
PRECOMMIT ?= pre-commit

.PHONY: all check install lint tests

all: check

# First run after a clone: the commit hooks plus the link into the game
# (scripts/link-addon.sh, which remembers the path in .wow-addons). Pass the
# game once -- its root, _retail_ or Interface/AddOns:
#
#   make install ADDONS="/path/to/World of Warcraft"
install:
	@if command -v $(PRECOMMIT) >/dev/null 2>&1; then \
		$(PRECOMMIT) install; \
	else \
		echo "pre-commit not found: install it for the commit hooks (CONTRIBUTING.md)"; \
	fi
	@sh scripts/link-addon.sh "$(ADDONS)"

# Everything a change must pass.
check: lint tests

# Static analysis and file hygiene through the pre-commit hooks, over every
# tracked file and the new ones not yet staged. Falls back to luacheck alone
# where pre-commit is not installed (the CI does not install it).
lint:
	files=$$(git ls-files --cached --others --exclude-standard); \
	if command -v $(PRECOMMIT) >/dev/null 2>&1; then \
		$(PRECOMMIT) run --files $$files; \
	else \
		$(LUACHECK) .; \
	fi

# The offline suite, against the WoW API mock (tests/wowmock.lua).
tests:
	$(LUAJIT) tests/run.lua
