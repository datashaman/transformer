core = require('./core')

home = require('./plugins/home')
user = require('./plugins/user')
contact = require('./plugins/contact')

app = core.createApp
    plugins: [ home, user, contact ]

core.runApp(app)
