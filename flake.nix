{
  description = "Modern presentation slides authoring environment: Markdown to Beamer PDF & Reveal.js HTML with BPMN support";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    bpmn-to-image = {
      url = "github:datakurre/bpmn-to-image";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    outline = {
      url = "github:datakurre/outline";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, bpmn-to-image, outline }:
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
          install -Dm644 ${./pandoc/metropolis.css} $out/pandoc/metropolis.css
          install -Dm644 ${./pandoc/slides.lua} $out/pandoc/slides.lua
        '';

        # BPMN renderer
        bpmnRenderer = bpmn-to-image.packages.${pkgs.stdenv.hostPlatform.system}.default;

        # Slides CLI application
        slides = pkgs.writeShellApplication {
          name = "slides";
          runtimeInputs = [
            pkgs.pandoc
            texliveEnv
            bpmnRenderer
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
              echo "  --html         Build Reveal.js HTML presentation (<deck.html>)" >&2
              echo "  --all          Build both PDF and HTML (default)" >&2
              echo "  --watch        Rebuild automatically whenever the markdown file changes" >&2
              echo "  --serve [port] Start a local HTTP server and live rebuild on changes (default port: 8000)" >&2
              echo "  -h, --help     Show this help message" >&2
              exit "''${1:-0}"
            }

            build_pdf=0
            build_html=0
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
                --html)
                  build_html=1
                  shift
                  ;;
                --all)
                  build_pdf=1
                  build_html=1
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
            if [ "$build_pdf" -eq 0 ] && [ "$build_html" -eq 0 ]; then
              build_pdf=1
              build_html=1
            fi

            # Watch mode
            if [ "$watch_mode" -eq 1 ]; then
              echo "Watching $input for changes (press Ctrl+C to stop)..." >&2
              build_flags=()
              [ "$build_pdf" -eq 1 ] && build_flags+=(--pdf)
              [ "$build_html" -eq 1 ] && build_flags+=(--html)
              status=0
              printf '%s\n' "$input" | entr -n "$0" "''${build_flags[@]}" "$input" || status=$?
              exit "$status"
            fi

            # Serve mode
            if [ "$serve_mode" -eq 1 ]; then
              echo "Starting preview server on http://localhost:$serve_port" >&2
              # Initial build
              "$0" --html "$input"
              
              # Start background watcher
              ( printf '%s\n' "$input" | entr -n "$0" --html "$input" ) &
              watcher_pid=$!
              
              trap 'kill $watcher_pid 2>/dev/null || true' EXIT INT TERM
              
              cd "$dir"
              python3 -m http.server "$serve_port"
              exit 0
            fi

            # Standard Build Mode
            tmp="$(mktemp -d)"
            trap 'rm -rf "$tmp"' EXIT
            export SLIDES_TMPDIR="$tmp"

            cd "$dir"

            # 1. Build HTML (Reveal.js)
            if [ "$build_html" -eq 1 ]; then
              pandoc -t revealjs --standalone \
                --css="${support}/pandoc/metropolis.css" \
                --lua-filter="${support}/pandoc/slides.lua" \
                --slide-level=2 \
                -V revealjs-url="https://unpkg.com/reveal.js@^5" \
                -V theme="white" \
                -o "$dir/$base.html" "$input"
              echo "Wrote $dir/$base.html"
            fi

            # 2. Build PDF (Beamer Metropolis)
            if [ "$build_pdf" -eq 1 ]; then
              pandoc -t beamer \
                --template="${support}/pandoc/beamer-metropolis.latex" \
                --lua-filter="${support}/pandoc/slides.lua" \
                --slide-level=2 \
                -o "$tmp/document.tex" "$input"

              if ! TEXINPUTS="$dir:$dir/..:${support}/pandoc::" \
                latexmk -pdf -recorder -interaction=nonstopmode -shell-escape -quiet \
                  -output-directory="$tmp" "$tmp/document.tex" >/dev/null 2>&1; then
                echo "LaTeX compilation error:" >&2
                grep -a -A 4 '^!' "$tmp/document.log" >&2 || true
                exit 1
              fi

              cp "$tmp/document.pdf" "$dir/$base.pdf"
              echo "Wrote $dir/$base.pdf"
            fi
          '';
          meta = {
            description = "Compile Markdown presentation slides to Beamer PDF and Reveal.js HTML";
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
            pkgs.pandoc
            pkgs.librsvg
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
