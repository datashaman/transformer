docs: docs/index.html

docs/index.html: index.coffee
	docco index.coffee

development:
	sudo npm install -g coffee-script foreman bower nodemon docco
	npm install
