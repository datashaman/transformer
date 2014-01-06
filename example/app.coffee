http = require('http')
_ = require('lodash')
transformer = require('transformer')
connect = require('connect')
RedisStore = require('connect-redis')(connect)


names = ['brand', 'menus', 'home', 'users', 'contacts']
components = _.map names, (name) -> require './components/' + name

config =
    secret: 'somesecret'
    components: components

app = connect()
    .use(connect.favicon())
    .use(connect.logger('dev'))
    .use(connect.static('public'))
    .use(connect.methodOverride())
    .use(connect.cookieParser())
    .use(connect.session(store: new RedisStore(), secret: config.secret))
    .use(connect.bodyParser())
    .use(connect.json())
    .use(connect.query())
    .use(transformer(config))

port = 1337
host = '127.0.0.1'

http.createServer(app).listen(port, host)
console.log 'Server running at http://' + host + ':' + port + '/'
