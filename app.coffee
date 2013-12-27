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

setupContextFilters = (filters) ->
    jsonFilter = require('json-filter')

    (req, res, next) ->
        req.locals = {}

        for [ params, callback ] in filters
            r = simplifyReq(req)
            filter = if typeof params is 'object' then params else { route: { name: params } }
            if jsonFilter(r, filter)
                _(req.locals).extend(callback(req))
        next()

addDebug = (req, window, $, weld, end) ->
    locals = _.clone(req.locals)
    _(locals).extend
        request: simplifyReq(req)

    fs.readFile req.locals.template, 'utf8', (err, template) ->
        throw err if err
        console.log template

        _(req.locals).extend
            html: template
            end: new Date()
            time: req.locals.end - req.locals.start

        $('#debug').html(JSON.stringify(simplifyReq(req), null, 4))

        end()

setupRoutes = (routes) ->
    matches = {}

    for route in routes
        route.pattern = murl(route.url)

    (req, res, next) ->
        if !matches[req.url]?
            for route in routes
                params = route.pattern(req.url)

                if params
                    matches[req.url] = [ route, params ]
                    break

        [ req.route, req.params] = matches[req.url] if matches[req.url]?

        next()

setupResponse = (callback) ->
    (req, res, next) ->
        template = fs.readFileSync(req.locals.template, 'utf8')

        jsdom = require('jsdom')
        document = jsdom.jsdom(template)
        req.window = window = document.parentWindow

        weldTag = document.createElement('script')
        weldTag.src = 'http://localhost:1337/scripts/weld.js'
        document.body.appendChild(weldTag)

        jsdom.jQueryify window, 'http://localhost:1337/scripts/jquery.min.js', ->
            window.weld(window.$('html')[0], req.locals, {
                map: (parent, element, key, val) ->
                    switch key
                        when 'username'
                            element.setAttribute('href', '/users/' + val)

                    console.log
                        parent: parent
                        element: element
                        key: key
                        val: val
            })
            res.end window.document.innerHTML

endResponse = (req, res) ->
    res.end()

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

filters = [
    [ ALL, (req) ->
        start: new Date()
    ]
    [ 'home', (req) ->
        title: 'Home'
        template: 'home.html'
    ]
    [ 'users', (req) ->
        title: 'Users'
        users: users
        template: 'users.html'
    ]
    [ 'user', (req) ->
        for user in users
            if req.params.username is user.username
                found = user
                break

        user: found
        title: 'User ' + user.username
        template: 'user.html'
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
    .use(setupResponse(addDebug))

http = require('http')
http.createServer(app).listen(1337, '127.0.0.1')

console.log 'Server running at http://127.0.0.0:1337/'
