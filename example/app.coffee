http = require('http')
_ = require('lodash')
transformer = require('transformer')
connect = require('connect')
RedisStore = require('connect-redis')(connect)
winston = require('winston')


config =
    logTransports: [
        new winston.transports.File
            filename: __dirname + '/logs/app.log'
            level: 'debug'
            raw: true
    ]
    secret: 'somesecret'
    components: _.map [
        'brand',
        'menus',
        'home',
        'users',
        'contacts'
    ], (name) ->
        require './components/' + name

app = connect()
    .use(connect.favicon())
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
