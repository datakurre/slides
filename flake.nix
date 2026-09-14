{
  description = "Modern presentation slides authoring environment: Markdown to Beamer PDF and Marp HTML with BPMN support";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    bpmn-to-image = {
      url = "github:datakurre/bpmn-to-image";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    bpmn-auto-layout = {
      url = "github:datakurre/bpmn-auto-layout";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    outline = {
      url = "github:datakurre/outline";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, bpmn-to-image, bpmn-auto-layout, outline }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      eachSystem = f: nixpkgs.lib.genAttrs systems (system: f (import nixpkgs {
        inherit system;
      }));
    in {
      packages = eachSystem (pkgs:
        let
          outlinePackage = outline.packages.${pkgs.stdenv.hostPlatform.system}.default;
        in rec {
        # TeX Live closure with Metropolis Beamer theme and required LaTeX packages
        texliveEnv = pkgs.texliveSmall.withPackages (ps: with ps; [
          appendixnumberbeamer
          beamer
          beamertheme-metropolis
          booktabs
          catchfile
          ccicons
          cm-super
          ec
          enumitem
          epstopdf
          etoolbox
          fancyvrb
          fira
          float
          fontaxes
          framed
          fvextra
          graphics
          hyperref
          ifplatform
          latex
          latexmk
          lineno
          microtype
          mweights
          fontawesome
          pgf
          pgfopts
          pgfplots
          preview
          translator
          ulem
          upquote
          xcolor
          xkeyval
          xstring
        ]);

        # Shared pandoc assets (templates, styles, filters)
        support = pkgs.runCommandLocal "slides-support" { } ''
          mkdir -p $out/pandoc
          install -Dm644 ${./pandoc/beamer-metropolis.latex} $out/pandoc/beamer-metropolis.latex
          install -Dm644 ${./pandoc/metropolis-marp.css} $out/pandoc/metropolis-marp.css
          install -Dm644 ${./pandoc/slides.lua} $out/pandoc/slides.lua
          install -Dm644 ${./pandoc/robotframework.xml} $out/pandoc/robotframework.xml
        '';

        # BPMN renderer
        bpmnRenderer = (bpmn-to-image.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [ ./nix/bpmn-to-image-boundary-events.patch ];
        }));
        bpmn = bpmn-auto-layout.packages.${pkgs.stdenv.hostPlatform.system}.default;

        # Slides CLI application
        slides = pkgs.writeShellApplication {
          name = "slides";
          runtimeInputs = [
            pkgs.pandoc
            pkgs.marp-cli
            texliveEnv
            bpmnRenderer
            bpmn
            pkgs.librsvg
            pkgs.ghostscript
            pkgs.ffmpeg
            pkgs.entr
            pkgs.coreutils
            pkgs.python3
            pkgs.gnugrep
            pkgs.findutils
          ];
          text = ''
            usage() {
              echo "Usage: slides [options] <deck.md>" >&2
              echo "" >&2
              echo "Options:" >&2
              echo "  --pdf          Build Beamer PDF presentation (<deck.pdf>)" >&2
              echo "  --marp         Build Marp HTML presentation (<deck.html>)" >&2
              echo "  --all          Build PDF and Marp HTML (default)" >&2
              echo "  --fast         Fast compilation mode (images instead of animations for BPMN)" >&2
              echo "  --watch        Rebuild automatically whenever the markdown file changes" >&2
              echo "  --serve [port] Start a local HTTP server and live rebuild on changes (default port: 8000)" >&2
              echo "  -h, --help     Show this help message" >&2
              exit "''${1:-0}"
            }

            build_pdf=0
            build_marp=0
            fast_mode=0
            watch_mode=0
            serve_mode=0
            serve_port=8000
            args=()

            while [ "$#" -gt 0 ]; do
              case "$1" in
                --pdf)
                  build_pdf=1
                  shift
                  ;;
                --marp)
                  build_marp=1
                  shift
                  ;;
                --all)
                  build_pdf=1
                  build_marp=1
                  shift
                  ;;
                --fast)
                  fast_mode=1
                  shift
                  ;;
                --watch)
                  watch_mode=1
                  shift
                  ;;
                --serve)
                  serve_mode=1
                  if [ "$#" -gt 1 ] && [[ "$2" =~ ^[0-9]+$ ]]; then
                    serve_port="$2"
                    shift 2
                  else
                    shift
                  fi
                  ;;
                -h|--help)
                  usage 0
                  ;;
                -*)
                  echo "Error: Unknown option $1" >&2
                  usage 2
                  ;;
                *)
                  args+=("$1")
                  shift
                  ;;
              esac
            done

            if [ -n "''${SLIDES_FAST:-}" ] && [ "$SLIDES_FAST" != "0" ] && [ "$SLIDES_FAST" != "false" ]; then
              fast_mode=1
            fi

            if [ "''${#args[@]}" -ne 1 ] || [ "''${args[0]##*.}" != "md" ]; then
              usage 2
            fi

            if [ ! -f "''${args[0]}" ]; then
              echo "Error: ''${args[0]}: file not found" >&2
              exit 1
            fi

            input="$(realpath "''${args[0]}")"
            dir="$(dirname "$input")"
            base="$(basename "$input" .md)"

            # Default to both PDF and HTML if neither is explicitly specified
            if [ "$build_pdf" -eq 0 ] && [ "$build_marp" -eq 0 ]; then
              build_pdf=1
              build_marp=1
            fi

            # Watch mode
            if [ "$watch_mode" -eq 1 ]; then
              echo "Watching $input for changes (press Ctrl+C to stop)..." >&2
              build_flags=()
              [ "$build_pdf" -eq 1 ] && build_flags+=(--pdf)
              [ "$build_marp" -eq 1 ] && build_flags+=(--marp)
              [ "$fast_mode" -eq 1 ] && build_flags+=(--fast)
              status=0
              printf '%s\n' "$input" | entr -n "$0" "''${build_flags[@]}" "$input" || status=$?
              exit "$status"
            fi

            # Serve mode
            if [ "$serve_mode" -eq 1 ]; then
              echo "Starting preview server on http://localhost:$serve_port" >&2
              serve_flags=(--marp)
              [ "$fast_mode" -eq 1 ] && serve_flags+=(--fast)
              # Initial build
              "$0" "''${serve_flags[@]}" "$input"
              
              # Start background watcher
              ( printf '%s\n' "$input" | entr -n "$0" "''${serve_flags[@]}" "$input" ) &
              watcher_pid=$!
              
              trap 'kill $watcher_pid 2>/dev/null || true' EXIT INT TERM
              
              cd "$dir"
              python3 -m http.server "$serve_port"
              exit 0
            fi

            # Standard Build Mode
            # Keep rendered media between rebuilds. Cache keys in the Lua filter
            # include source contents, so stale outputs are invalidated safely.
            work="$(mktemp -d)"
            trap 'rm -rf "$work"' EXIT
            cache="''${SLIDES_CACHE_DIR:-''${XDG_CACHE_HOME:-$HOME/.cache}/slides}"
            mkdir -p "$cache"
            export SLIDES_CACHE_DIR="$cache"

            pandoc_flags=()
            if [ "$fast_mode" -eq 1 ]; then
              export SLIDES_FAST=1
              pandoc_flags+=(-M fast=true)
            fi

            cd "$dir"

            # 1. Build Marp HTML from filtered Markdown. Pandoc materializes
            # diagrams and media before Marp turns the Markdown into HTML.
            if [ "$build_marp" -eq 1 ]; then
              marp_source="$work/$base-marp.md"
              pandoc -t gfm \
                --lua-filter="${support}/pandoc/slides.lua" \
                --slide-level=2 \
                -M marp=true \
                -M theme=metropolis \
                "''${pandoc_flags[@]}" \
                -o "$marp_source" "$input"
              marp --html --allow-local-files --theme metropolis \
                --theme-set="${support}/pandoc/metropolis-marp.css" \
                -o "$dir/$base.html" "$marp_source"
              # Marp's default runtime uses xMinYMid, which left-aligns the
              # 16:9 canvas in wide browser windows. Center it like a PDF page.
              python3 - "$dir/$base.html" "$input" <<'PY'
from pathlib import Path
import html
import re
import sys

path = Path(sys.argv[1])
html_text = path.read_text()
# Keep the HTML base size aligned with Beamer's shared `fontsize` metadata.
source = Path(sys.argv[2]).read_text()
match = re.search(r'^fontsize:\s*([0-9.]+)pt\s*$', source, re.MULTILINE)
base_size = float(match.group(1)) * 2.5 if match else 30
css_variable = f':root {{ --slide-base-font-size: {base_size:g}px; }}'
html_text = html_text.replace('</style>', css_variable + '</style>', 1)
html_text = html_text.replace('xMinYMid meet', 'xMidYMid meet')

SETTING_KEYWORDS = {
    "Library", "Resource", "Variables", "Documentation", "Metadata",
    "Suite Setup", "Suite Teardown", "Test Setup", "Test Teardown",
    "Test Template", "Test Timeout", "Test Tags", "Task Setup",
    "Task Teardown", "Task Template", "Task Timeout", "Task Tags",
    "Setup", "Teardown", "Template", "Timeout", "Tags", "Arguments", "Return"
}

CONTROL_KEYWORDS = {
    "VAR", "IF", "ELSE IF", "ELSE", "END", "FOR", "IN", "IN RANGE",
    "IN ZIP", "IN ENUMERATE", "WHILE", "TRY", "EXCEPT", "FINALLY",
    "RETURN", "CONTINUE", "BREAK"
}

def span(cls, text):
    return f'<span class="{cls}">{html.escape(text)}</span>'

def highlight_rf_args(arg_text):
    token_pattern = re.compile(
        r'(?P<var>[\$@&%]{[^\}]+}(?:\[[^\]]+\])?)'
        r'|(?P<param>\b[\w\.:\-]+=)'
    )
    pos = 0
    parts = []
    for m in token_pattern.finditer(arg_text):
        if m.start() > pos:
            parts.append(html.escape(arg_text[pos:m.start()]))
        if m.group('var'):
            parts.append(span('hljs-variable', m.group('var')))
        elif m.group('param'):
            parts.append(span('hljs-attr', m.group('param')))
        pos = m.end()
    if pos < len(arg_text):
        parts.append(html.escape(arg_text[pos:]))
    return "".join(parts)

def highlight_robotframework(code_text: str) -> str:
    raw_code = html.unescape(code_text)
    output_lines = []
    for line in raw_code.splitlines():
        comment_idx = line.find('#')
        comment_part = ""
        if comment_idx != -1:
            comment_part = span('hljs-comment', line[comment_idx:])
            line = line[:comment_idx]
            
        if not line.strip():
            output_lines.append(html.escape(line) + comment_part)
            continue
            
        if re.match(r'^\s*\*+[\s\w]+\*+.*$', line):
            output_lines.append(span('hljs-section', line) + comment_part)
            continue
            
        indent_match = re.match(r'^(\s+)(.*)$', line)
        if indent_match:
            indent = indent_match.group(1)
            rest = indent_match.group(2)
            
            if re.match(r'^\.\.\.(?:\s{2,}|\s*$)', rest):
                dots_m = re.match(r'^(\.\.\.)(\s*.*)$', rest)
                output_lines.append(html.escape(indent) + span('hljs-keyword', dots_m.group(1)) + highlight_rf_args(dots_m.group(2)) + comment_part)
                continue
                
            first_word_m = re.match(r'^([A-Za-z]+(?:\s+[A-Za-z]+)*?)(?:\s{2,}|\s*$)(.*)$', rest)
            if first_word_m and first_word_m.group(1) in CONTROL_KEYWORDS:
                output_lines.append(html.escape(indent) + span('hljs-keyword', first_word_m.group(1)) + highlight_rf_args(rest[len(first_word_m.group(1)):]) + comment_part)
                continue
                
            var_assign_m = re.match(r'^([\$@&%]{[^\}]+}\s*=\s*)(.*)$', rest)
            if var_assign_m:
                var_str = var_assign_m.group(1)
                after_var = var_assign_m.group(2)
                kw_m = re.match(r'^([^\s].*?)(?:\s{2,}|\s*$)(.*)$', after_var)
                if kw_m and kw_m.group(1):
                    kw = kw_m.group(1)
                    after_kw = after_var[len(kw):]
                    output_lines.append(html.escape(indent) + highlight_rf_args(var_str) + span('hljs-title', kw) + highlight_rf_args(after_kw) + comment_part)
                else:
                    output_lines.append(html.escape(indent) + highlight_rf_args(var_str) + highlight_rf_args(after_var) + comment_part)
                continue
                
            kw_m = re.match(r'^([^\s].*?)(?:\s{2,}|\s*$)(.*)$', rest)
            if kw_m:
                kw = kw_m.group(1)
                after_kw = rest[len(kw):]
                output_lines.append(html.escape(indent) + span('hljs-title', kw) + highlight_rf_args(after_kw) + comment_part)
            else:
                output_lines.append(html.escape(indent) + highlight_rf_args(rest) + comment_part)
        else:
            words_m = re.match(r'^([A-Za-z]+(?:\s+[A-Za-z]+)*?)(?:\s{2,}|\s*$)(.*)$', line)
            if words_m and words_m.group(1) in SETTING_KEYWORDS:
                output_lines.append(span('hljs-keyword', words_m.group(1)) + highlight_rf_args(line[len(words_m.group(1)):]) + comment_part)
                continue
                
            if words_m and words_m.group(1) in CONTROL_KEYWORDS:
                output_lines.append(span('hljs-keyword', words_m.group(1)) + highlight_rf_args(line[len(words_m.group(1)):]) + comment_part)
                continue
                
            var_assign_m = re.match(r'^([\$@&%]{[^\}]+}\s*=\s*)(.*)$', line)
            if var_assign_m:
                var_str = var_assign_m.group(1)
                after_var = var_assign_m.group(2)
                kw_m = re.match(r'^([^\s].*?)(?:\s{2,}|\s*$)(.*)$', after_var)
                if kw_m and kw_m.group(1):
                    kw = kw_m.group(1)
                    after_kw = after_var[len(kw):]
                    output_lines.append(highlight_rf_args(var_str) + span('hljs-title', kw) + highlight_rf_args(after_kw) + comment_part)
                else:
                    output_lines.append(highlight_rf_args(var_str) + highlight_rf_args(after_var) + comment_part)
                continue
                
            output_lines.append(span('hljs-title', line) + comment_part)
            
    return "\n".join(output_lines)

def highlight_block(m):
    return m.group(1) + highlight_robotframework(m.group(2)) + '</code></pre>'

html_text = re.sub(
    r'(<pre><code\s+class="[^"]*(?:robotframework|robot)[^"]*">)(.*?)(?=</code></pre>)</code></pre>',
    highlight_block,
    html_text,
    flags=re.DOTALL
)

path.write_text(html_text)
PY
              echo "Wrote $dir/$base.html"
            fi

            # 2. Build PDF (Beamer Metropolis)
            if [ "$build_pdf" -eq 1 ]; then
              pandoc -t beamer \
                --template="${support}/pandoc/beamer-metropolis.latex" \
                --syntax-definition="${support}/pandoc/robotframework.xml" \
                --lua-filter="${support}/pandoc/slides.lua" \
                --slide-level=2 \
                "''${pandoc_flags[@]}" \
                -o "$work/document.tex" "$input"

              if ! TEXINPUTS="$dir:$dir/..:${support}/pandoc::" \
                latexmk -pdf -recorder -interaction=nonstopmode -shell-escape -quiet \
                  -output-directory="$work" "$work/document.tex" >/dev/null 2>&1; then
                echo "LaTeX compilation error:" >&2
                grep -a -A 4 '^!' "$work/document.log" >&2 || true
                exit 1
              fi

              cp "$work/document.pdf" "$dir/$base.pdf"
              echo "Wrote $dir/$base.pdf"
            fi
          '';
          meta = {
            description = "Compile Markdown presentation slides to Beamer PDF and Marp HTML";
            mainProgram = "slides";
          };
        };

        # Interactive terminal outline editor (from outline flake input)
        outlineEditor = outlinePackage;

        default = slides;
        outline = outlineEditor;
        outline-editor = outlineEditor;
      });

      devShells = eachSystem (pkgs: {
        default = pkgs.mkShell {
          name = "slides-dev";
          packages = [
            self.packages.${pkgs.stdenv.hostPlatform.system}.slides
            self.packages.${pkgs.stdenv.hostPlatform.system}.outline-editor
            self.packages.${pkgs.stdenv.hostPlatform.system}.texliveEnv
            self.packages.${pkgs.stdenv.hostPlatform.system}.bpmnRenderer
            self.packages.${pkgs.stdenv.hostPlatform.system}.bpmn
            pkgs.pandoc
            pkgs.librsvg
            pkgs.ghostscript
            pkgs.ffmpeg
            pkgs.entr
            pkgs.gnumake
            pkgs.python3
            pkgs.poppler-utils
          ];
        };
      });

      apps = eachSystem (pkgs: {
        default = {
          type = "app";
          program = "${self.packages.${pkgs.stdenv.hostPlatform.system}.slides}/bin/slides";
        };
        slides = {
          type = "app";
          program = "${self.packages.${pkgs.stdenv.hostPlatform.system}.slides}/bin/slides";
        };
        outline = {
          type = "app";
          program = "${self.packages.${pkgs.stdenv.hostPlatform.system}.outline-editor}/bin/outline-editor";
        };
        outline-editor = {
          type = "app";
          program = "${self.packages.${pkgs.stdenv.hostPlatform.system}.outline-editor}/bin/outline-editor";
        };
      });
    };
}
