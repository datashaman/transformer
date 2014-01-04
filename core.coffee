# jsdom environment needed for server-side rendering with Transparency
jsdom = require('jsdom')

# pattern matching and parameter extraction from the URL
murl = require('murl')

# Functional goodness
_ = require('lodash')

# Used for reading in templates and jsdom scripts
fs = require('fs')

# Server-side layout and partial rendering
jade = require('jade')

# object matching and filtering for dispatch
jsonFilter = require('json-filter')

# Observer pattern for interaction with plugins (mostly)
events = require('events')


# Simplify the request object down to the things
# we will likely be filtering on
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

# Core logic of the application
setupApp = (config) ->
    # Main emitter for pub/sub of events
    emitter = new events.EventEmitter()

    _(config).defaults
        plugins: []
        listeners: {}
        routes: []
        filters: []
        viewPath: './views/'
        directives: {}
        headers: []

    # Utility function to bind a listener funtionally
    bindListener = (listener, event) ->
        emitter.on(event, listener)

    # Bind any globally configured listeners
    _.forEach config.listeners, bindListener

    # Bind the plugins' configure listeners first
    # since they influence the running of further listeners
    _.forEach config.plugins, (plugin) ->
        bindListener(plugin.listeners.configure, 'configure') if plugin.listeners?.configure?

    # Allow configure listeners to affect the config
    emitter.emit 'configure', config

    # Merge the plugins' components into the config dictionary
    _.forEach config.plugins, (plugin) ->
        # Bind the plugin's non-configure listeners
        # The configure listeners are already bound
        _.forEach _.omit(plugin.listeners, 'configure'), bindListener

        # Merge the plugin config into the main config
        config.routes = config.routes.concat(plugin.routes) if plugin.routes?
        _(config.directives).merge(plugin.directives) if plugin.directives?
        config.filters = config.filters.concat(plugin.filters) if plugin.filters?
        config.menus = config.menus.concat(plugin.menus) if plugin.menus?
        config.headers = config.headers.concat(plugin.headers) if plugin.headers?

    # Load the source for jquery and transparency (used later by jsdom)
    jquery = fs.readFileSync('./bower_components/jquery/jquery.min.js', 'utf8')
    transparency = fs.readFileSync('./node_modules/transparency/dist/transparency.min.js', 'utf8')

    views = {}
    matches = {}

    # For each route defined, create and store a URL generator (using murl)
    routes = _.reduce(config.routes, ((routes, route) ->
        routes[route.name] = route.generator = murl(route.url)
        routes), {})

    emitter.emit 'afterConfigure', config, routes

    # Return connect middleware
    (req, res, next) ->
        # Start with a fresh locals dictionary
        req.locals =
            url: (name, args...) ->
                routes[name](args)

        # Store the configured global directives (for Jade) 
        # in the request
        req.directives = config.directives

        # We only want to match against the pathname of the request URL
        pathname = req._parsedUrl.pathname

        # Memoize the result in a matches collection
        unless matches[pathname]?
            _.find config.routes, (route) ->
                params = route.generator(pathname)

                # If a match is found, memoize the route and parameters found
                # and break out of the loop
                if params?
                    matches[pathname] = [ route, params ]
                    return true

        # Store the memoized match results in the request
        # for the next middleware in the chain
        [ req.route, req.params] = matches[pathname] if matches[pathname]?

        # If there is a matched route, process it
        if req.route?
            # Create a simplified view of the request for running through the filters
            r = simplifyReq(req)

            # Loop through the defined filters looking for ones where there's a match
            for [ params, callback ] in config.filters
                # The filter to match on could be a string or an object.
                # If it's a string, it's the equivalent of a filter on route name, with GET method
                filter = if typeof params is 'object' then params else { method: 'GET', route: { name: params } }

                # Use json-filter to pattern match the filter requirements
                # against the simplified request
                if jsonFilter(r, filter)
                    # Run the callback with the request and response
                    # and merge the results into the request locals dictionary
                    _(req.locals).merge(callback(req, res))

                    # If the response has been redirected by a filter,
                    # shortcircuit out of the loop
                    if res.statusCode == 302
                        break

            # Prepare the response if we have not been redirected
            if res.statusCode != 302
                # If a view is defined by a filter, prepare an HTML response
                if req.locals._view
                    emitter.emit 'htmlLocals', config, req.locals

                    # Memoize the compiled views
                    viewName = req.locals._view
                    unless false and views[viewName]?
                        filename = config.viewPath + viewName + '.jade'
                        views[viewName] = jade.compile(fs.readFileSync(filename, 'utf8'), {
                            filename: filename,
                            pretty: true
                        })

                    # Setup headers HTML
                    req.locals.headers = _.map config.headers, (header) ->
                        jade.render header

                    jsdom.env
                        html: views[viewName](req.locals)
                        src: [
                            jquery,
                            transparency
                        ]
                        done: (errors, window) ->
                            # Render using transparency
                            window.$('html').render(req.locals, req.directives)

                            # Remove any artefacts introduced by jsdom
                            window.$('script.jsdom').remove()

                            # Write out the rendered response
                            res.writeHead 200, { 'Content-Type': 'text/html' }
                            res.end window.document.doctype + window.document.outerHTML
                # Assume a JSON response of the locals dictionary is required
                else
                    res.writeHead 200, { 'Content-Type': 'application/json' }
                    res.end JSON.stringify(req.locals)
        # No route match found, emit a 404
        else
            res.writeHead 404
            res.end 'Page Not Found'

module.exports =
    createApp: (config) ->
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
            .use(setupApp(config))

    runApp: (app, port=1337, host='127.0.0.1') ->
        http = require('http')
        http.createServer(app).listen(port, host)

        console.log 'Server running at http://' + host + ':' + port + '/'
