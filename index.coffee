path = require('path')
glob = require('glob')

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

# Delegator
delegate = require('delegate')

# Load the source for jquery and transparency (used later by jsdom)
jquery = fs.readFileSync('./bower_components/jquery/jquery.min.js', 'utf8')
transparency = fs.readFileSync('./bower_components/transparency/dist/transparency.min.js', 'utf8')


class Server
    constructor: (@config) ->
        @registry = {}
        @views = {}
        @matches = {}
        @values = {}

        @emitter = new delegate.EventEmitter()
        delegate @, @emitter

        @configure()

    configure: ->
        _(@config).defaults
            components: []
            listeners: {}
            routes: []
            filters: []
            viewPath: './views/'
            directives: {}
            headers: []
            footers: []

        @bindListeners()

        # Allow configure listeners to affect the config
        @emit 'configure', @config

        _.forEach @config.components, @configureComponent, @

        # For each route defined, create and store a URL generator (using murl)
        @routes = _.reduce(@config.routes, ((routes, route) ->
            routes[route.name] = route.generator = murl(route.url)
            routes), {})

        @emit 'afterConfigure', @config, @routes

    bindListeners: ->
        # Bind any globally configured listeners
        _.forEach @config.listeners, @bindListener, @

        # Bind the components' configure listeners first
        # since they influence the running of further listeners
        configureComponents = _.filter @config.components, (component) ->
            component.listeners?.configure?
        bindConfigureListener = (component) ->
            @bindListener(component.listeners.configure, 'configure')
        _.forEach configureComponents, bindConfigureListener, @

    configureComponent: (component) ->
        # Bind the component's non-configure listeners
        # The configure listeners are already bound
        listeners = _.omit(component.listeners, 'configure')
        _.forEach listeners, @bindListener, @

        # Merge the component config into the main config
        @config.routes = @config.routes.concat(component.routes) if component.routes?
        _(@config.directives).merge(component.directives) if component.directives?
        @config.filters = @config.filters.concat(component.filters) if component.filters?
        @config.headers = @config.headers.concat(component.headers) if component.headers?
        @config.footers = @config.footers.concat(component.footers) if component.footers?

        # Allow components to do their own configuration per component
        @emit 'configureComponent', @config, component

        # Return nothing so that we don't inadvertently stop the loop
        return

    set: (key, value) ->
        delete @values[key]
        @registry[key] = value

    get: (key, args...) ->
        value = @registry[key]
        if value instanceof Function
            @values[key] = value(args...) unless @values[key]?
            @values[key]
        else
            value

    # Simplify the request object down to the things
    # we will likely be filtering on
    simplifyReq: (req) ->
        r = _.pick req, [
            'route', 'params', 'locals',
            'httpVersion', 'headers', 'trailers',
            'url', 'originalUrl', 'method',
            'originalMethod', 'body', 'files',
            'query', 'cookies', 'session'
        ]
        _.merge r,
            parsedUrl: req._parsedUrl
            startTime: req._startTime

    # Utility function to bind a listener functionally
    bindListener: (listener, event) ->
        @on(event, listener)

    resolveRoute: (pathname) ->
        # Memoize the result in matches collection
        unless @matches[pathname]?
            _.find @config.routes, (route) =>
                params = route.generator(pathname)

                # If a match is found, memoize the route and parameters found
                # and break out of the loop
                if params?
                    @matches[pathname] = [ route, params ]
                    return true

        # Store the memoized match results in the request
        # for the next middleware in the chain
        @matches[pathname]

    applyFilters: (req, res) ->
        # Create a simplified view of the request for running through the filters
        r = @simplifyReq(req)

        # Loop through the defined filters looking for ones where there's a match
        for [ params, callback ] in @config.filters
            # The filter to match on could be a string or an object.
            # If it's a string, it's the equivalent of a filter on route name, with GET method
            filter = if typeof params is 'object' then params else { method: 'GET', route: { name: params } }

            # Use json-filter to pattern match the filter requirements
            # against the simplified request
            if jsonFilter(r, filter)
                # Run the callback with the request and response
                # and merge the results into the request locals dictionary
                _(req.locals).merge(callback.call(@, req, res))

                # If req.locals now has a _view property,
                # shortcircuit out of the loop
                break if req.locals._view?

                # If the response has been redirected by a filter,
                # shortcircuit out of the loop
                break if res.statusCode == 302

    redirect: (res, location) ->
        res.statusCode = 302
        res.setHeader('Location', location)
        res.end('Redirecting...')

    findComponentView: (viewName) ->
        fileName = viewName + '.jade'
        files = glob.sync('components/*/views/**/*.jade')
        _.find files, (file) ->
            file.slice(-fileName.length) == fileName

    compileView: (viewName, locals) ->
        # filename = @config.viewPath + viewName + '.jade'
        filename = @findComponentView(viewName)

        view = jade.compile(fs.readFileSync(filename, 'utf8'), {
            filename: filename,
            pretty: true
        })

        # Setup HTML for header / footer
        # by prepping a locals dictionary
        # with rendered blocks
        locals = _.clone(locals)

        for block in ['headers', 'footers']
            markup = _.map @config[block], (source) ->
                jade.render source
            locals[block] = markup.join('\n')

        locals.url = (name, args...) =>
            @routes[name](args)

        # Render the HTML using a compiled Jade template
        view(locals)

    renderView: (locals) ->
        viewName = locals._view

        unless @views[viewName]?
            @views[viewName] = @compileView(viewName, locals)

        @views[viewName]

    renderHTML: (req, res) ->
        # Allow listeners to configure html locals
        @emit 'htmlLocals', @config, req.locals

        html = @renderView(req.locals)

        jsdom.env
            html: html
            src: [
                jquery
                transparency
            ]
            done: (errors, window) =>
                # Render using transparency
                window.$('html').render req.locals, @config.directives

                # Write out the rendered response
                res.writeHead 200, { 'Content-Type': 'text/html' }
                res.end window.document.doctype + window.document.outerHTML

    renderJSON: (req, res) ->
        res.writeHead 200, { 'Content-Type': 'application/json' }
        res.end JSON.stringify(req.locals)

    renderError: (req, res, statusCode, message) ->
        res.writeHead statusCode
        res.end message

    # connect middleware
    middleware: (req, res) ->
        req.locals = {}

        if match = @resolveRoute(req._parsedUrl.pathname)
            [ req.route, req.params ] = match

        # If there is a matched route, process it
        if req.route?
            @applyFilters req, res

            # Prepare the response if we have not been redirected already
            if res.statusCode != 302
                # If a view is defined by a filter, prepare an HTML response
                if req.locals._view
                    @renderHTML req, res

                # Assume a JSON response of the locals dictionary is required
                else
                    @renderJSON req, res

        # No route match found, emit a 404
        else
            @renderError req, res, 404, 'Page Not Found'

configureServer = (config) ->
    server = new Server(config)

    (req, res, next) ->
        server.middleware(req, res, next)

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
            .use(configureServer(config))

    runApp: (app, port=1337, host='127.0.0.1') ->
        http = require('http')
        http.createServer(app).listen(port, host)

        console.log 'Server running at http://' + host + ':' + port + '/'
