foreman:
	nf start

docs: docs/core.html

docs/core.html: core.coffee
	docco core.coffee
