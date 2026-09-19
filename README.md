# Modern Slide Deck Authoring Environment

A reproducible Markdown-first presentation authoring environment that compiles into professional **LaTeX Beamer (Metropolis theme)** PDFs and linear **Marp** HTML presentations, featuring native **BPMN 2.0 diagram embedding** and video support.

Powered by [Nix Flakes](https://nixos.org), [Pandoc](https://pandoc.org), and [`bpmn-to-image`](https://github.com/datakurre/bpmn-to-image).

---

## Features

- **Markdown Master Format**: Write clean, version-controllable presentations in Markdown.
- **Dual Output Compilation**:
  - **Beamer PDF**: Modern 16:9 widescreen slides styled with the [Metropolis theme](https://github.com/matze/mtheme) and Fira Sans typography.
- **Marp HTML**: Linear, Markdown-native HTML presentations with no two-dimensional navigation.
- **BPMN 2.0 Process Diagrams**: Embed `.bpmn` files or inline ```` ```bpmn ```` blocks (automatically rendered to vector SVG/PDF, animated formats, or — in Marp HTML — a live interactive simulator via `bpmn-to-image`).
- **Video & Animations**: Native HTML5 `<video>` embedding in HTML slides and automated poster frame extraction with `ffmpeg` in Beamer PDFs.
- **Live Development**: Live reload on file change (`--watch`) and built-in local preview server (`--serve`).
- **Reproducible Nix Toolchain**: Pinned TeX Live closure, Pandoc, `bpmn-to-image`, `librsvg`, and `ffmpeg` managed via `flake.nix`.

---

## Quick Start

### 1. Enter the Environment

```bash
make shell
# or directly:
nix develop
```

### 2. Build Slides with the `slides` CLI

```bash
# Build both PDF and HTML for a presentation
slides examples/demo.md

# Build only PDF or only HTML
slides --pdf examples/demo.md
slides --marp examples/demo.md

# Fast mode: static images instead of animations for BPMN diagrams
slides --fast examples/demo.md

# Watch mode: automatically recompile on save
slides --watch examples/demo.md

# Start a local preview server with live reload
slides --serve 8000 examples/demo.md
```

You can also run without entering a subshell using `nix run`:

```bash
nix run . -- examples/demo.md
nix run . -- --pdf examples/demo.md
nix run . -- --marp examples/demo.md
nix run . -- --fast examples/demo.md
nix run . -- --watch examples/demo.md
nix run . -- --serve 8000 examples/demo.md
nix run .#outline-editor -- examples/demo.md   # Interactive outline editor
```

### 3. Make Targets

```bash
make build              # Build all presentations into build/
make fast               # Build all presentations in fast mode (images instead of animations)
make pdf                # Build only PDF presentations
make marp               # Build Marp HTML presentations
make watch FILE=deck.md # Watch a specific presentation
make serve FILE=deck.md # Live preview server
make outline FILE=deck.md # Edit presentation outline in terminal
make vendor             # Initialize and update git submodules (vendor/outline)
make clean              # Remove generated artifacts
```

---

## Authoring Guide

### Frontmatter Configuration

Configure slide metadata and customize palette colors in the YAML frontmatter:

```yaml
---
title: "Presentation Title"
subtitle: "Optional Subtitle"
author: "Author Name"
date: "2026-08-30"
institute: "University of Jyväskylä"
logo: "images/logo.png" # Path to logo image (.png, .eps, or .svg)
colors:
  primary: "#002957" # Palette primary (headers, frame titles, standouts)
  accent: "#F1563F" # Accent color (progress bar, title separators)
aspectratio: "169" # 16:9 widescreen (default) or "43" (4:3)
fontsize: 12pt # Shared PDF and HTML base size: 10pt, 11pt, 12pt, 14pt
fast: false # Fast compilation mode (render static images instead of animations)
---
```
`fontsize` controls both outputs. For HTML, the value is converted using the
presentation scale `12pt = 30px`.

### Slide Syntax & Features

#### 1. Sections and Standard Slides
```markdown
# Section Title (Generates a Metropolis section page)

## Slide Title

- Bullet point 1
- Bullet point 2
  - Sub-bullet
```

#### 2. Standout Inverted Slides
Use `## Title {.standout}` or `## {.standout}` for full-bleed inverted slides:
```markdown
## {.standout}

Write Markdown.
Generate Beamer PDF & Marp HTML.
```

#### 3. Multi-Column Layouts
Use Pandoc fenced divs:
```markdown
::: columns
::: {.column width="48%"}
### Left Column
- Item A
- Item B
:::

::: {.column width="48%"}
### Right Column
- Item C
- Item D
:::
:::
```

#### 4. BPMN 2.0 Process Models
Include external `.bpmn` diagram files:
```markdown
![](diagrams/order-process.bpmn)
```
Or with animation scenario:
```markdown
![](diagrams/order-process.bpmn){scenario="scenarios/happy-path.toml"}
```
Animated BPMN diagrams are rendered as animated WebP images in Marp HTML. Beamer PDF
uses the middle frame of the same token simulation as its static representation.
When fast mode is enabled (via CLI `--fast`, `make fast`, frontmatter `fast: true`, or per-diagram `fast="true"`), static SVG/PDF images are rendered directly without generating animations.
Or write inline BPMN XML blocks:
````markdown
```bpmn
<?xml version="1.0" encoding="UTF-8"?>
<bpmn:definitions ...>
  ...
</bpmn:definitions>
```
````

In Marp HTML, a diagram can also be embedded as a **live, interactive simulator** instead of a pre-rendered image or animation — a real `bpmn-js` viewer running in the reader's browser, with play/pause and click-to-steer-a-gateway, the same as the interactive tool itself:
```markdown
![](diagrams/order-process.bpmn){simulator="true"}
```
or, for an inline block, add the `simulator` class: ` ```{.bpmn .simulator} `. There's no scenario to script here — unlike the pre-rendered animation, it's driven live by whoever is viewing the slide. Ignored (falls back to a static frame) in Beamer PDF, which can't run live JavaScript.

#### 5. Embedded Videos
```markdown
![](media/demo.mp4)
```
- In **Marp HTML**: Renders a native `<video>` player with autoplay/controls.
- In **Beamer PDF**: Extracts a poster snapshot using `ffmpeg` and links to the media.

#### 6. Code Syntax Highlighting
```markdown
```nix
{
  description = "Modern presentation toolchain";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
}
```
```

#### 7. Speaker Notes
```markdown
::: notes
Remember to mention the fallback plan.
:::
```
Marp keeps these available as speaker notes; Beamer turns them into
`\note{}`. The outline editor exposes them as each item's **Notes** field.

---

## Project Structure

```
.
├── flake.nix                       # Nix Flake toolchain and CLI package
├── flake.lock                      # Pinned dependency lockfile
├── Makefile                        # High-level make targets (make shell => nix develop)
├── README.md                       # User guide & documentation
├── AGENTS.md                       # AI Agent orientation & architecture guide
├── CLAUDE.md                       # Claude Code guidance
├── pandoc/
│   ├── beamer-metropolis.latex     # Pandoc Beamer Metropolis template
│   ├── metropolis-marp.css         # Marp theme matching Metropolis palette
│   └── slides.lua                  # Lua filter for BPMN, SVG, video & standouts
├── outline/
│   └── outline-editor.ts           # Interactive terminal outline editor
└── examples/
    ├── demo.md                     # Comprehensive feature showcase presentation
    ├── camunda-meetup-fi-2024-06.md
    ├── camunda-open-source-ecosystem.md
    ├── pulumi-overview.md
    └── diagrams/
        └── sample-process.bpmn     # BPMN 2.0 XML diagram
```

---

## License

MIT
