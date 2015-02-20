
deploy: .docker
	docker run --rm -u $$(id -u):$$(id -g) -v $$PWD:/site -w /site vizowl/ffwd-fish /app/ffwd-fish-site build
	
.docker: site.hs
	docker build -t "vizowl/ffwd-fish" .
	touch $@
