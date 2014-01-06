_ = require('lodash')
transformer = require('transformer')

names = ['brand', 'menus', 'home', 'users', 'contacts']
components = _.map names, (name) -> require './components/' + name

app = transformer.createApp
    secret: 'somesecret'
    components: components

transformer.runApp app
