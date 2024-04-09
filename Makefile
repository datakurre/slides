TEXFILE ?= camunda-open-source-ecosystem.tex

.PHONY: all
all: build

%.nav: %.tex
	@latexmk -shell-escape -quiet $<

%.pdf: %.tex images
	@latexmk -pdf -recorder -interaction=nonstopmode -shell-escape -use-make -quiet $<

%.pdf: %.tex images
	@latexmk -pdf -recorder -interaction=nonstopmode -shell-escape -use-make -quiet $<

build: camunda-open-source-ecosystem.pdf
	mkdir -p build/alt
	mv *.pdf build
	echo '<meta http-equiv="refresh" content= "0;url=camunda-open-source-ecosystem.pdf" />' > build/index.html
	touch build/.nojekyll

.PHONY: watch
watch:
	@latexmk -pvc -pdf -recorder -interaction=nonstopmode -shell-escape -use-make $(TEXFILE)

.PHONY: cache
cache:
	nix-store --query --references $(nix-instantiate shell.nix) |\
	xargs nix-store --realise | xargs nix-store --query --requisites |\
	cachix push datakurre

.PHONY: clean
clean:
	@latexmk -C -quiet
	@rm -f *.nav *.snm *.fls *.vrb _minted-$(TEXFILE)/*
	@if [ -d _minted-$(TEXFILE) ]; then rmdir _minted-$(TEXFILE); fi
