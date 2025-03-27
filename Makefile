# Makefile
SHELL := /bin/bash
.SHELLFLAGS := -u -o pipefail -c

CHART_NAME := helm-template-utils
CHART_FILE := Chart.yaml
TEMPLATE_FILE := templates/_util.tpl

TEST_CHART := tests
TEST_CHART_FILE := $(TEST_CHART)/$(CHART_FILE)
TEST_UNITS := $(TEST_CHART)/unit
TEST_VALUES := $(TEST_CHART)/values.yaml

.PHONY: deps
deps:
	@echo "📦 Updating dependencies..."
	@helm dependency update --skip-refresh $(TEST_CHART)

.PHONY: test unittest test-clean
test: test-clean deps
	@echo "🔍 Running template test for helpers..."
	@helm template --debug test $(TEST_CHART) -f $(TEST_VALUES)

unittest: test-clean deps
	@echo "🔍 Running unit tests for helpers..."
	@helm unittest $(TEST_CHART) -qsf "$(TEST_UNITS)/*"

test-clean:
	@echo "🧹 Cleaning up test artifacts..."
	@rm -rf $(TEST_CHART)/charts
	@rm -rf $(TEST_UNITS)/__snapshot__
	@rm -f $(TEST_CHART)/Chart.lock


.PHONY: bump-patch bump-minor bump-major release release-patch release-minor release-major dist-clean
DIST_DIR := ./dist
DIST_REMOTE ?= github
DIST_USER ?= 3coma3

DIST_VERSION = $(shell yq e '.version' $(CHART_FILE))

define bump_version
	@echo "🔼 Bumping $(1) version..."
	@$(SHELL) $(SHELL_FLAGS) -c '\
	IFS="." read -r major minor patch <<< "$(DIST_VERSION)"; \
	case "$(1)" in \
		major) (( major++, minor=0, patch=0 )) ;; \
		minor) (( minor++, patch=0 )) ;; \
		patch) (( patch++ )) ;; \
	esac; \
	new_version="$$major.$$minor.$$patch"; \
	echo "✅ New version: $$new_version"; \
	yq e -i ".version = \"$$new_version\"" $(CHART_FILE); \
	yq e -i ".version = \"$$new_version\"" $(TEST_CHART_FILE); \
	yq e -i ".dependencies[] |= select(.name == \"$(CHART_NAME)\") .version = \"$$new_version\"" $(TEST_CHART_FILE); \
	echo -e "\n🔐 Unlocking GPG key..."; \
	gpg --clearsign <<< "signing warmup" > /dev/null; \
	echo -e "\n🚀 Publishing release..."; \
	git add $(CHART_FILE) $(TEST_CHART_FILE); \
	git commit -S -m "chore(release): $$new_version"; \
	git tag -s "$$new_version" -m "release: $$new_version"; \
	git push $(DIST_REMOTE) main --follow-tags; \
	echo -e "🎉 Published release $$new_version\n"'
endef

bump-patch:
	$(call bump_version,patch)

bump-minor:
	$(call bump_version,minor)

bump-major:
	$(call bump_version,major)

release:
	@echo "📦 Packaging chart from main branch..."
	@mkdir -p $(DIST_DIR)
	@helm package . --destination $(DIST_DIR)
	@echo -e "\n🧮 Generating index.yaml..."
	@helm repo index $(DIST_DIR) --url "https://$(DIST_USER).github.io/$(CHART_NAME)"
	@git checkout gh-pages
	@mv $(DIST_DIR)/* .
	@echo -e "\n🚀 Publishing chart..."
	@git add $(CHART_NAME)-$(DIST_VERSION).tgz index.yaml
	@git commit -S -m "chore(release): $(DIST_VERSION)"
	@git push $(DIST_REMOTE) gh-pages
	@git checkout main
	@echo -e "🎉 Published chart $(DIST_VERSION)\n"

dist-clean:
	@echo -e "🧹 Cleaning up release artifacts..."
	@rm -rf $(DIST_DIR)

release-patch: bump-patch release dist-clean
release-minor: bump-minor release dist-clean
release-major: bump-major release dist-clean
