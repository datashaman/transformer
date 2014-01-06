docs: docs/core.html

docs/core.html: core.coffee
	docco core.coffee

development:
	sudo npm install -g coffee-script foreman bower nodemon docco
	npm install
	bower install
