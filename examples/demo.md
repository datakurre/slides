---
title: "Modern Presentation Slides"
subtitle: "Authoring with Markdown, Beamer Metropolis & Marp"
author: "Asko Soukka"
date: "2026-08-30"
institute: "University of Jyväskylä"
colors:
  primary: "#002957"
  accent: "#F1563F"
---

# Introduction

## Markdown-first Slide Authoring

- **Master format in Markdown**: Clean, version-controllable, distraction-free
- **Dual output**:
  - **PDF**: Professional LaTeX Beamer using the *Metropolis* theme
  - **HTML**: Linear *Marp* presentations for web delivery
- **Embedded BPMN**: Direct rendering of `.bpmn` diagrams via `bpmn-to-image`
- **Reproducible environment**: Managed with Nix Flakes (`nix develop`)

## {.standout}

Write Markdown.

Generate Beamer PDF & Marp HTML.

# BPMN Process Diagrams

## Embedded BPMN 2.0 Diagram

Directly include `.bpmn` process models without manual export:

![](media/demo/diagrams/sample-process.bpmn)

The diagram is rendered to SVG/PDF automatically at build time.

# Layouts & Formatting

## Two-Column Layout

::: columns
::: {.column width="48%"}
### Architecture
* Declarative Nix Flake
* Pandoc Lua filters
* TeX Live Metropolis
* Marp HTML
:::

::: {.column width="48%"}
### Features
* Live reload with `--watch`
* Code syntax highlighting
* Native HTML5 video support
* Standout inverted slides
:::
:::

## Code Syntax Highlighting

```nix
{
  description = "Modern slide deck authoring";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.bpmn-to-image.url = "github:datakurre/bpmn-to-image";

  outputs = { self, nixpkgs, bpmn-to-image }: {
    # Seamless toolchain
  };
}
```

## Tables and Data

| Feature | LaTeX Beamer (PDF) | Marp (HTML) |
|:---|:---:|:---:|
| Metropolis Theme | Yes (Native) | Yes (CSS) |
| BPMN Diagrams | Vector PDF | Vector SVG |
| Video Playback | Poster Frame | HTML5 Native |
| Offline Viewing | Standalone PDF | Standalone HTML |

## {.standout}

Questions & Discussion
