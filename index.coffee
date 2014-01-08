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

# Logging
winston = require('winston')

# Load the source for jquery and transparency (used later by jsdom)
jquery = fs.readFileSync(__dirname + '/node_modules/jquery/dist/jquery.min.js', 'utf8')
transparency = fs.readFileSync(__dirname + '/node_modules/transparency/dist/transparency.min.js', 'utf8')


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
            logTransports: [
                new winston.transports.Console
                    json: true
            ]

        @logger = new winston.Logger
            transports: @config.logTransports
        @logger.cli()

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
        @logger.info 'configure', component: component.name

        # Bind the component's non-configure listeners
        # The configure listeners are already bound
        listeners = _.omit(component.listeners, 'configure')
        _.forEach listeners, @bindListener, @

        # Merge the component config into the main config
        @config.routes = @config.routes.concat(component.routes) if component.routes?
        _(@config.directives).merge(component.directives) if component.directives?

        if component.filters?
            filters = _.forEach component.filters, (filter) ->
                filter.component = component

            @config.filters = @config.filters.concat(filters)

        @config.headers = @config.headers.concat(component.headers) if component.headers?
        @config.footers = @config.footers.concat(component.footers) if component.footers?

        # Allow components to do their own configuration per component
        @emit 'configureComponent', @config, component

        # Return nothing so that we don't inadvertently stop the loop
        return

    # Service Locator pattern
    set: (key, value) ->
        delete @values[key]
        @registry[key] = value

    # Service Locator pattern
    # If the registry contains a function, run it with args... and cache the result
    # Otherwise assume the registry contains the value required
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

        @matches[pathname]

    applyFilters: (req, res) ->
        # Create a simplified view of the request for running through the filters
        r = @simplifyReq(req)

        # Loop through the defined filters looking for ones where there's a match
        for filter in @config.filters
            [ params, callback ] = filter

            # The filter to match on could be a string or an object.
            # If it's a string, it's the equivalent of a filter on route name, with GET method
            if typeof params is 'string'
                params = { method: 'GET', route: { name: params } }

            # Use json-filter to pattern match the filter requirements
            # against the simplified request
            if jsonFilter(r, params)
                @logger.debug 'filter-match', { params: JSON.stringify(params), url: r.url }

                # Run the callback with the request and response
                # and merge the results into the request locals dictionary
                _(req.locals).merge(callback.call(@, req, res))

                # If req.locals now has a _view property,
                # shortcircuit out of the loop
                if req.locals._view?
                    req.locals._component = filter.component
                    req.locals._filter = filter
                    break

                # If the response has been redirected by a filter,
                # shortcircuit out of the loop
                break if res.statusCode == 302

    redirect: (res, location) ->
        res.statusCode = 302
        res.setHeader('Location', location)
        res.end('Redirecting...')

    findComponentView: (locals) ->
        componentName = locals._component.name
        viewName = locals._view
        'components/' + componentName + '/views/' + viewName + '.jade'

    compileView: (locals) ->
        filename = @findComponentView(locals)
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

    cacheView: (locals) ->
        componentName = locals._component.name
        viewName = locals._view

        key = componentName + '-' + viewName

        @views[key] = @compileView(locals) unless @views[key]?
        @views[key]

    renderHTML: (req, res) ->
        # Allow listeners to configure html locals
        @emit 'htmlLocals', @config, req.locals

        html = @cacheView(req.locals)

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

    # return connect middleware
    terminator: ->
        (req, res) =>
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

module.exports = (config) ->
    server = new Server(config)
    server.terminator()
