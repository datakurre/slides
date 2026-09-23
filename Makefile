FILE ?= examples/demo.md
MARKDOWN ?= $(wildcard examples/*.md) ploneconf-2026.md wrobocon-2026.md
PORT ?= 8000
FAST ?= 0
FAST_FLAG = $(if $(filter 1 true yes,$(FAST)),--fast,)
QUICK ?= 0
QUICK_FLAG = $(if $(filter 1 true yes,$(QUICK)),--quick,)
NOCACHE ?= 0
NOCACHE_FLAG = $(if $(filter 1 true yes,$(NOCACHE)),--no-cache,)
# Must mirror the `slides` wrapper's own cache directory default (flake.nix),
# or `make clean` and the actual build will disagree about where the render
# cache lives. The wrapper only falls back to this when SLIDES_CACHE_DIR
# isn't already set in the environment.
CACHE_DIR := $(if $(SLIDES_CACHE_DIR),$(SLIDES_CACHE_DIR),$(if $(XDG_CACHE_HOME),$(XDG_CACHE_HOME),$(HOME)/.cache)/slides)

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
		nix run . -- --all $(FAST_FLAG) $(QUICK_FLAG) $(NOCACHE_FLAG) "$$doc" || exit 1; \
	done
	@for doc in $(MARKDOWN); do \
		base=$${doc%.md}; \
		cp -f "$$base.pdf" "$$base.html" build/ 2>/dev/null || true; \
	done
	@cp -rf images media pulumi-images examples/diagrams build/ 2>/dev/null || true
	@touch build/.nojekyll
	@python3 pandoc/generate-index.py
	@echo "Build complete in ./build"

.PHONY: fast
fast: ## Build all markdown presentations in fast mode (images instead of animations)
	@$(MAKE) build FAST=1

.PHONY: quick
quick: ## Build all markdown presentations with low-FPS animations
	@$(MAKE) build QUICK=1

.PHONY: pdf
pdf: ## Build only PDF presentations
	@mkdir -p build
	@for doc in $(MARKDOWN); do \
		echo "==> Building PDF for $$doc"; \
		nix run . -- --pdf $(FAST_FLAG) $(NOCACHE_FLAG) "$$doc" || exit 1; \
	done
	@cp examples/*.pdf build/ 2>/dev/null || true

.PHONY: marp
marp: ## Build Marp HTML presentations
	@mkdir -p build
	@for doc in $(MARKDOWN); do \
		echo "==> Building Marp HTML for $$doc"; \
		nix run . -- --marp $(FAST_FLAG) $(NOCACHE_FLAG) "$$doc" || exit 1; \
	done
	@cp examples/*.html build/ 2>/dev/null || true

.PHONY: watch
watch: ## Watch and auto-rebuild on changes (usage: make watch FILE=examples/demo.md)
	@nix run . -- --watch $(FAST_FLAG) $(NOCACHE_FLAG) $(FILE)

.PHONY: serve
serve: ## Start local HTTP preview server with live reload (usage: make serve FILE=examples/demo.md PORT=8000)
	@nix run . -- --serve $(PORT) $(FAST_FLAG) $(NOCACHE_FLAG) $(FILE)

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
clean: ## Clean generated PDF, HTML, build artifacts, and the render cache
	@rm -rf build
	@rm -f examples/*.pdf examples/*.html *.pdf *.html
	@rm -f *.nav *.snm *.fls *.vrb *.aux *.log *.toc *.out
	@rm -f "$(CACHE_DIR)"/bpmn-*.svg "$(CACHE_DIR)"/bpmn-anim-*.webp \
		"$(CACHE_DIR)"/svg-*.pdf "$(CACHE_DIR)"/video-poster-*.png \
		"$(CACHE_DIR)"/eps-*.pdf "$(CACHE_DIR)"/eps-*.png \
		"$(CACHE_DIR)"/inline-*.bpmn "$(CACHE_DIR)"/symbol-*.bpmn
