_ = require('lodash')
core = require('./core')

names = ['brand', 'menus', 'home', 'user', 'contact']
components = _.map names, (name) -> require './components/' + name

app = core.createApp
    secret: 'somesecret'
    components: components

core.runApp app
