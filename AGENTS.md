# Presentation Slides: Agent-Driven Development Guide

## Project Overview

This repository provides a Markdown-first presentation authoring environment that compiles into both:
1. **Beamer LaTeX (PDF)**: Professional widescreen (16:9) slides styled with the modern **Metropolis** (`beamertheme-metropolis`) theme and **Fira Sans** typography.
2. **Marp (HTML)**: Linear Markdown-native HTML presentations using the same palette and media pipeline.

The environment is packaged as a reproducible **Nix Flake** (`flake.nix`) providing the `slides` CLI, a pinned TeX Live closure, Pandoc templates/filters, the [`bpmn-autolayout`](https://github.com/datakurre/bpmn-autolayout) flake for generating BPMN DI layout, and the [`bpmn-to-image`](https://github.com/datakurre/bpmn-to-image) flake for embedding BPMN 2.0 process models.

---

## Core Architecture

```
Markdown Document (.md)
       │
       ├──[ Pandoc + slides.lua + beamer-metropolis.latex ]──> Beamer PDF (.pdf)
       │
       └──[ Pandoc + slides.lua + metropolis-marp.css + Marp ]──> Marp HTML (.html)
```

### Components

- **`flake.nix`**: Flake definition exposing:
  - `packages.<system>.slides` / `default`: The main CLI tool.
  - `packages.<system>.outline-editor` / `outline`: Terminal outline editor for interactive slide manipulation.
  - `packages.<system>.texliveEnv`: Minimal required TeX Live closure (Beamer, Metropolis, Fira, PGF/TikZ, fontawesome, microtype).
   - `packages.<system>.support`: Bundled templates, Lua filters, and CSS styles.
   - `packages.<system>.bpmnAutoLayout`: In-place BPMN DI layout tool from `github:datakurre/bpmn-autolayout`.
   - `packages.<system>.bpmnRenderer`: Headless BPMN renderer from `github:datakurre/bpmn-to-image`.
   - `devShells.<system>.default`: Development environment with all compilers and tools (`pandoc`, `texliveEnv`, `bpmn-autolayout`, `bpmn-to-image`, `outline-editor`, `librsvg`, `ffmpeg`, `entr`, `python3`, `poppler-utils`).
- **`vendor/outline/`**: Git submodule (`https://github.com/datakurre/outline.git`) providing the terminal outline editor as its own Nix flake input (`github:datakurre/outline`). Built via `outline.packages.<system>.default`.
- **`pandoc/beamer-metropolis.latex`**: LaTeX Beamer template configuring Metropolis, Fira Sans, 16:9 widescreen, custom theme colors, syntax highlighting, and pandoc macros.
- **`pandoc/slides.lua`**: Pandoc Lua filter handling:
  - `.bpmn` diagram conversion to vector PDF (LaTeX) and vector SVG / animated WebP / live interactive simulator (HTML).
   - Inline ```` ```bpmn ```` code blocks; generated BPMN files are always run through `bpmn-autolayout` before rendering.
  - `.svg` conversion to `.pdf` via `rsvg-convert` for pdflatex.
  - `.eps` conversion to `.pdf` via `epstopdf` / `ghostscript`.
  - `.mp4` / `.webm` video handling (poster snapshot for PDF, `<video>` for HTML).
  - Automatic relative path resolution against the document source directory.
  - **`pandoc/metropolis-marp.css`**: Marp theme matching the PDF palette with linear navigation and responsive layouts.

---

## CLI & Flake Commands

```bash
# Run via nix without entering subshell
nix run . -- examples/demo.md                  # Builds demo.pdf and demo.html
nix run . -- --pdf examples/demo.md            # Builds only demo.pdf
nix run . -- --marp examples/demo.md           # Builds only demo.html
nix run . -- --fast examples/demo.md           # Fast mode: static images instead of animations
nix run . -- --watch examples/demo.md          # Live rebuilds on file change
nix run . -- --serve 8000 examples/demo.md     # Starts HTTP preview server
nix run .#outline-editor -- examples/demo.md   # Interactive outline editor

# Development shell
nix develop                                    # Enter shell with all tools
make shell                                     # Equivalent to nix develop

# Make targets
make build                                     # Build all presentations into build/
make fast                                      # Build all presentations in fast mode
make pdf                                       # Build all PDF presentations
make marp                                      # Build all Marp HTML presentations
make watch FILE=examples/demo.md               # Watch specific file
make serve FILE=examples/demo.md               # Preview server for specific file
make outline FILE=examples/demo.md             # Launch interactive outline editor
make vendor                                    # Initialize and update git submodules (vendor/outline)
make clean                                     # Clean build directory and temporary files
```

---

## Authoring Guidelines & Parity Rules

1. **Frontmatter Configuration**:
   ```yaml
   ---
   title: "Presentation Title"
   subtitle: "Subtitle"
   author: "Author Name"
   date: "2026-08-30"
   institute: "University of Jyväskylä"
   logo: "images/logo.png"
   colors:
     primary: "#002957"
     accent: "#F1563F"
   aspectratio: "169"
   fontsize: 12pt
   ---
   ```
2. **Standout Slides**:
   Use `## Title {.standout}` or `## {.standout}` for focused, full-bleed inverted slides.
3. **BPMN Diagrams**:
    - File reference: `![](diagrams/process.bpmn)` or `![](diagrams/process.bpmn){scenario="scenario.toml"}`
    - Run generated or checked-in `.bpmn` files through `bpmn-autolayout` before rendering or committing them:
      `nix run .#bpmnAutoLayout -- diagrams/process.bpmn`
    - Inline BPMN blocks are laid out automatically by the `slides` filter. External source files are not modified during a slide build.
   - Inline block:
     ````markdown
     ```bpmn
     <?xml version="1.0" encoding="UTF-8"?>
     ...
     ```
     ````
   - **Live simulator (Marp HTML only)**: `![](diagrams/process.bpmn){simulator="true"}` or a ` ```{.bpmn .simulator} ` inline block embeds an interactive `bpmn-js` viewer with token simulation (play/pause, click a gateway to steer it) instead of a pre-rendered image/animation — see `bpmn-to-image --format html`. Ignored for `scenario`/`animated`/`fast`; ignored entirely (falls back to a static frame) for Beamer PDF, which can't run live JS.
4. **Columns**:
   Use Pandoc fenced divs for multi-column layouts:
   ```markdown
   ::: columns
   ::: {.column width="48%"}
   Left content
   :::
   ::: {.column width="48%"}
   Right content
   :::
   :::
   ```
5. **Videos**:
   Reference `![](video.mp4)`. In HTML, it renders a full `<video>` element with autoplay/controls. In PDF, it extracts a poster frame using `ffmpeg`.
6. **Speaker Notes**:
   Use a Pandoc fenced div for speaker notes; Marp hides it from the slide surface and Beamer renders it into `\note{}`:
   ```markdown
   ::: notes
   Remember to mention the fallback plan.
   :::
   ```
   The outline editor reads and writes these blocks as each item's **Notes** field (`N` key).

---

## Maintenance & Testing

Always test both PDF and HTML outputs before reporting completion:
```bash
make clean
make build
```
Verify generated PDFs using `pdftotext` from `poppler-utils`:
```bash
nix shell nixpkgs#poppler-utils --command pdftotext build/demo.pdf -
```

## Agent Sandbox
```toml agent-sandbox
[network]
allowed_hosts = [
    "*.nixos.org:443",
    "*.cachix.org:443",
    "*.github.com:443",
    "*.github.io:443",
]
```
