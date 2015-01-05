
SITE_DIR=_site
HTML = $(addsuffix .html, $(basename $(shell find site -iname "*.rmd")))

all:
	make site

site: $(HTML) $(SITE_DIR) site/assets/**/*
	cp -r site/assets $(HTML) $(SITE_DIR);\
	git subtree push --prefix _site origin gh-pages

$(SITE_DIR):
	rm -r _site; mkdir -p $(SITE_DIR)

site/%.html:site/%.rmd
	cd $(@D); echo $(<F); Rscript -e 'require("rmarkdown"); rmarkdown::render("$(<F)")'
