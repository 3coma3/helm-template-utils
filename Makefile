TEST_CHART := tests
TEST_FILE := $(TEST_CHART)/unittest/envlist.yaml
VALUES_FILE := $(TEST_CHART)/values.yaml
HELPERS_FILE := templates/_helpers.tpl
TEST_HELPERS_FILE := $(TEST_CHART)/$(HELPERS_FILE)

.PHONY: test unittest clean

test: clean
	@echo "🔍 Running template test for helpers..."
	@helm dependency update --skip-refresh $(TEST_CHART)
	@helm template test $(TEST_CHART) -f $(VALUES_FILE)

unittest: clean $(TEST_HELPERS_FILE)
	@echo "🔍 Running unit tests for helpers..."
	@helm unittest $(TEST_CHART) -sf $(TEST_FILE)

$(TEST_HELPERS_FILE): $(HELPERS_FILE)
	@echo "🧩 Copying helpers into test chart..."
	@cp $(HELPERS_FILE) $(TEST_HELPERS_FILE)

clean:
	@echo "🧹 Cleaning up test artifacts..."
	@rm -rf $(TEST_CHART)/charts
	@rm -f $(TEST_CHART)/Chart.lock
