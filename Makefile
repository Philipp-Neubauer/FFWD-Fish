
deploy: .docker
	docker run --rm -u $$(id -u):$$(id -g) -v $$PWD/site:/site -w /site vizowl/ffwd-fish /app/ffwd-fish-site build
	git checkout gh-pages 
	cp -r site/_site/* .
	git add .
	git commit -mupdate
	git push origin gh-pages
	git checkout master
	
.docker: site.hs
	docker build -t "vizowl/ffwd-fish" site
	touch $@
