FILE ?= examples/demo.md
MARKDOWN ?= $(wildcard examples/*.md)
PORT ?= 8000

.PHONY: all
all: build

.PHONY: help
help: ## Show this help message
	@grep -Eh '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}' | uniq

.PHONY: build
build: ## Build all markdown presentations (PDF and HTML) into build/
	@mkdir -p build
	@for doc in $(MARKDOWN); do \
		echo "==> Building $$doc"; \
		nix run . -- --all "$$doc" || exit 1; \
	done
	@cp -f examples/*.pdf examples/*.html build/ 2>/dev/null || true
	@cp -rf images pulumi-images examples/diagrams build/ 2>/dev/null || true
	@touch build/.nojekyll
	@python3 pandoc/generate-index.py
	@echo "Build complete in ./build"

.PHONY: pdf
pdf: ## Build only PDF presentations
	@mkdir -p build
	@for doc in $(MARKDOWN); do \
		echo "==> Building PDF for $$doc"; \
		nix run . -- --pdf "$$doc" || exit 1; \
	done
	@cp examples/*.pdf build/ 2>/dev/null || true

.PHONY: html
html: ## Build only HTML presentations
	@mkdir -p build
	@for doc in $(MARKDOWN); do \
		echo "==> Building HTML for $$doc"; \
		nix run . -- --html "$$doc" || exit 1; \
	done
	@cp examples/*.html build/ 2>/dev/null || true

.PHONY: watch
watch: ## Watch and auto-rebuild on changes (usage: make watch FILE=examples/demo.md)
	@nix run . -- --watch $(FILE)

.PHONY: serve
serve: ## Start local HTTP preview server with live reload (usage: make serve FILE=examples/demo.md PORT=8000)
	@nix run . -- --serve $(PORT) $(FILE)

.PHONY: outline
outline: ## Interactive outline editor (usage: make outline FILE=examples/demo.md)
	@nix run .#outline-editor -- $(FILE)

.PHONY: vendor
vendor: ## Initialize and update git submodules (vendor/outline)
	git submodule update --init --recursive

.PHONY: shell
shell: ## Enter the Nix development environment
	@nix develop

.PHONY: clean
clean: ## Clean generated PDF, HTML and build artifacts
	@rm -rf build
	@rm -f examples/*.pdf examples/*.html *.pdf *.html
	@rm -f *.nav *.snm *.fls *.vrb *.aux *.log *.toc *.out
