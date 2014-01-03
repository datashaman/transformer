core = require('./core')

home = require('./plugins/home')
user = require('./plugins/user')
contact = require('./plugins/contact')

app = core.createApp
    secret: 'somesecret'
    plugins: [ home, user, contact ]
    directives: {
        menus: {
        }
    }

core.runApp(app)
