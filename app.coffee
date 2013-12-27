jsdom = require('jsdom')
murl = require('murl')
_ = require('underscore')
fs = require('fs')

simplifyReq = (req) ->
    route: req.route
    params: req.params
    locals: req.locals
    httpVersion: req.httpVersion
    headers: req.headers
    trailers: req.trailers
    url: req.url
    originalUrl: req.originalUrl
    parsedUrl: req._parsedUrl
    method: req.method
    originalMethod: req.originalMethod
    body: req.body
    files: req.files
    query: req.query
    cookies: req.cookies
    session: req.session
    startTime: req._startTime

setupRoutes = (routes) ->
    matches = {}

    for route in routes
        route.pattern = murl(route.url)

    (req, res, next) ->
        if !matches[req.url]?
            for route in routes
                params = route.pattern(req._parsedUrl.pathname)

                if params
                    matches[req.url] = [ route, params ]
                    break

        [ req.route, req.params] = matches[req.url] if matches[req.url]?

        next()

setupContextFilters = (filters) ->
    jsonFilter = require('json-filter')

    (req, res, next) ->
        req.locals = {}
        req.directives = {}

        r = simplifyReq(req)

        for [ params, callback ] in filters
            filter = if typeof params is 'object' then params else { route: { name: params } }
            if jsonFilter(r, filter)
                _(req.locals).extend(callback(req))

        next()

renderResponse = (req, res, next) ->
    jquery = fs.readFileSync('./bower_components/jquery/jquery.min.js', 'utf-8')
    transparency = fs.readFileSync('./node_modules/transparency/dist/transparency.min.js', 'utf-8')

    jsdom.env
        file: 'views/' + req.locals._view + '.html'
        src: [
            jquery,
            transparency
        ]
        done: (errors, window) ->
            window.$('html').render(req.locals, req.directives)
            window.$('script.jsdom').remove()
            res.end window.document.doctype + window.document.outerHTML

routes = [
    { name: 'users', url: '/users' }
    { name: 'user', url: '/users/{username}' }
    { name: 'home', url: '/' }
]

ALL = {}

users = [{
    username: 'datashaman'
    firstName: 'Marlin'
    lastName: 'Forbes'
}, {
    username: 'slartibartfast'
    firstName: 'Slarti'
    lastName: 'BartFast'
}]

directives =
    user:
        username:
            href: ->
                '/users/' + @username

filters = [
    [ ALL, (req) ->
        start: new Date()
    ]
    [ 'home', (req) ->
        title: 'Home'
        _view: 'home'
    ]
    [ 'users', (req) ->
        req.directives.users = directives.user

        title: 'Users'
        users: users
        _view: 'users'
    ]
    [ 'user', (req) ->
        req.directives.user = directives.user

        for user in users
            if req.params.username is user.username
                found = user
                break

        user: found
        title: 'User ' + user.username
        _view: 'user'
    ]
]

connect = require('connect')
RedisStore = require('connect-redis')(connect)

app = connect()
    .use(connect.favicon())
    .use(connect.logger('dev'))
    .use(connect.static('public'))
    .use(connect.methodOverride())
    .use(connect.cookieParser())
    .use(connect.session(store: new RedisStore(), secret: 'somesecret'))
    .use(connect.bodyParser())
    .use(connect.json())
    .use(connect.query())
    .use(setupRoutes(routes))
    .use(setupContextFilters(filters))
    .use(renderResponse)

http = require('http')
http.createServer(app).listen(1337, '127.0.0.1')

console.log 'Server running at http://127.0.0.0:1337/'
