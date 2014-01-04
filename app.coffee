core = require('./core')

brand = require('./plugins/brand')
menus = require('./plugins/menus')
home = require('./plugins/home')
user = require('./plugins/user')
contact = require('./plugins/contact')

app = core.createApp
    secret: 'somesecret'
    plugins: [ brand, menus, home, user, contact ]

core.runApp(app)
