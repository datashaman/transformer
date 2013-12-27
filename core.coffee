jsdom = require('jsdom')
murl = require('murl')
_ = require('lodash')
fs = require('fs')
jade = require('jade')

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

setupDirectives = (config) ->
    (req, res, next) ->
        req.directives = config.directives
        next()

setupContextFilters = (filters) ->
    jsonFilter = require('json-filter')

    (req, res, next) ->
        req.locals = {}

        r = simplifyReq(req)

        for [ params, callback ] in filters
            filter = if typeof params is 'object' then params else { method: 'GET', route: { name: params } }
            if jsonFilter(r, filter)
                _(req.locals).merge(callback(req, res))
                if res.statusCode == 302
                    break

        next()

renderResponse = (config) ->
    jquery = fs.readFileSync('./bower_components/jquery/jquery.min.js', 'utf-8')
    transparency = fs.readFileSync('./node_modules/transparency/dist/transparency.min.js', 'utf-8')

    (req, res, next) ->
        if res.statusCode != 302
            req.locals.menus = config.menus

            fileName = config.viewPath + req.locals._view + '.jade'
            fn = jade.compile(fs.readFileSync(fileName, 'utf-8'),
                filename: fileName)

            console.log req.locals

            jsdom.env
                html: fn(req.locals)
                src: [
                    jquery,
                    transparency
                ]
                done: (errors, window) ->
                    window.$('html').render(req.locals, req.directives)
                    window.$('script.jsdom').remove()

                    res.end window.document.doctype + window.document.outerHTML

module.exports =
    createApp: (config) ->
        _(config).defaults
            viewPath: './views/'
            secret: 'somesecret'
            plugins: []
            routes: []
            filters: []
            directives: {}
            menus: []

        _(config.plugins).each (plugin) ->
            config.routes = config.routes.concat(plugin.routes) if plugin.routes?
            _(config.directives).merge(plugin.directives) if plugin.directives?
            config.filters = config.filters.concat(plugin.filters) if plugin.filters?
            config.menus = config.menus.concat(plugin.menus) if plugin.menus?

        connect = require('connect')
        RedisStore = require('connect-redis')(connect)

        connect()
            .use(connect.favicon())
            .use(connect.logger('dev'))
            .use(connect.static('public'))
            .use(connect.methodOverride())
            .use(connect.cookieParser())
            .use(connect.session(store: new RedisStore(), secret: config.secret))
            .use(connect.bodyParser())
            .use(connect.json())
            .use(connect.query())
            .use(setupRoutes(config.routes))
            .use(setupDirectives(config))
            .use(setupContextFilters(config.filters))
            .use(renderResponse(config))

    runApp: (app, port=1337, host='127.0.0.1') ->
        http = require('http')
        http.createServer(app).listen(port, host)

        console.log 'Server running at http://' + host + ':' + port + '/'
