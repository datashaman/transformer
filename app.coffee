core = require('./core')

menus = require('./plugins/menus')
home = require('./plugins/home')
user = require('./plugins/user')
contact = require('./plugins/contact')

app = core.createApp
    secret: 'somesecret'
    plugins: [ menus, home, user, contact ]

core.runApp(app)
