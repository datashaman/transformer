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
        @resources = {}
        @views = {}
        @matches = {}
        @values = {}

        @emitter = new delegate.EventEmitter()
        delegate @, @emitter

        @configure()

    configure: ->
        _.defaults @config,
            components: []
            listeners: {}
            routes: []
            filters: []
            resources: []
            viewPath: './views/'
            directives: {}
            headers: []
            footers: []
            logTransports: [
                new winston.transports.Console()
            ]

        @logger = new winston.Logger
            transports: @config.logTransports

        @logger.cli()

        @bindListeners()

        # Allow configure listeners to affect the config
        @emit 'configure', @config

        _.forEach @config.components, @mergeComponentConfig, @

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

    mergeComponentConfig: (component) ->
        _.defaults component,
            routes: []
            listeners: {}
            routes: []
            directives: {}
            resources: {}
            headers: []
            footers: []

        @logger.debug 'merge-config', { component: component }

        # Bind the component's non-configure listeners
        # The configure listeners are already bound
        _.forEach _.omit(component.listeners, 'configure'), @bindListener, @

        # Merge the component config into the main config
        _.merge @config, component, (a, b) ->
            if _.isArray(a) then a.concat(b) else undefined

        _.forEach component.resources, (resource, name) =>
            @set(name, resource)

        _.forEach component.filters, (filter) ->
            filter.component = component

        # Allow components to do their own configuration per component
        @emit 'configureComponent', @config, component

        # Return nothing so that we don't inadvertently stop the loop
        return

    setLocal: (values) ->
        _.merge @locals, values

    call: (callback, args...) ->
        callback.call @, args...

    # Service Locator pattern
    set: (key, value) ->
        @resources[key] = value

    # Service Locator pattern
    get: (key, set) ->
        value = @resources[key]
        if value instanceof Function
            # Run function to get value with callback to hand execution to
            value.call(@, set)
        else
            # Execute the callback with the value
            set.call(@, value)

    # Simplify the request object down to the things
    # we will likely be filtering on
    simplifyReq: ->
        _.merge _.pick(@req, [
            'route', 'params', 'locals',
            'httpVersion', 'headers', 'trailers',
            'url', 'originalUrl', 'method',
            'originalMethod', 'body', 'files',
            'query', 'cookies', 'session'
        ]), {
            parsedUrl: @req._parsedUrl
            startTime: @req._startTime
        }

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

    getParams: (params) ->
        # The filter to match on could be a string or an object.
        # If it's a string, it's the equivalent of a filter on '<method> <route.name>'
        if typeof params is 'string'
            parts = params.split(' ')
            {
                method: parts.shift().toUpperCase()
                route:
                    name: parts.join(' ')
            }
        else
            params

    applyFilters: (req, filters, fallback) ->
        return fallback.call(@) unless filters? and filters.length > 0

        filter = _.first(filters)

        [ originalParams, callback ] = filter
        params = @getParams(originalParams)

        done = =>
            @applyFilters req, _.rest(filters), fallback

        # Use json-filter to pattern match the filter requirements
        # against the simplified request
        if jsonFilter(req, params)
            @logger.debug 'filter', { component: filter.component.name, params: params, url: req.url }
            callback.call @, done
        else
            done()

    render: (viewName, extra={}) ->
        @logger.debug 'render', { viewName: viewName, extra: extra }

        _.merge @locals, extra

        # Allow listeners to configure html locals
        @emit 'htmlLocals', @config, @locals

        html = @cacheView(viewName)

        jsdom.env
            html: html
            src: [
                jquery
                transparency
            ]
            done: (errors, window) =>
                # Render using transparency
                window.$('html').render @locals, @config.directives

                # Write out the rendered response
                @res.writeHead 200, { 'Content-Type': 'text/html' }
                @res.end window.document.doctype + window.document.outerHTML

    redirect: (location) ->
        @logger.debug 'redirect', { location: location }

        @res.statusCode = 302
        @res.setHeader('Location', location)
        @res.end('Redirecting...')

    findComponentView: (viewName) ->
        [ componentName, viewName ] = viewName.split('/')
        'components/' + componentName + '/views/' + viewName + '.jade'

    compileView: (viewName) ->
        filename = @findComponentView(viewName)
        view = jade.compile(fs.readFileSync(filename, 'utf8'), {
            filename: filename,
            pretty: true
        })

        locals = _.defaults _.clone(@locals),
            url: (name, args...) =>
                @routes[name](args)

        # Setup HTML for header / footer
        # by prepping a locals dictionary
        # with rendered blocks
        _.merge locals, _.object _.map ['headers', 'footers'], (block) =>
            [ block, _.map(@config[block], (source) -> jade.render source).join('\n') ]

        # Render the HTML using a compiled Jade template
        view(locals)

    cacheView: (viewName) ->
        @views[viewName] = @compileView(viewName) unless @views[viewName]?
        @views[viewName]

    renderJSON: ->
        @res.writeHead 200, { 'Content-Type': 'application/json' }
        @res.end JSON.stringify(@req.locals)

    renderError: (statusCode, message) ->
        @logger.warn 'error', { url: @req.url, statusCode: statusCode, message: message }
        @res.writeHead statusCode
        @res.end message

    # return connect middleware
    terminator: ->
        (req, res) =>
            @req = req
            @res = res

            @locals = @req.locals = {}
            @session = @req.session
            @params = @req.params

            if match = @resolveRoute(@req._parsedUrl.pathname)
                @logger.debug 'route', { route: match[0], params: match[1] }
                [ @req.route, @req.params ] = match

            # If there is a matched route, process it
            if @req.route?
                req = @simplifyReq()
                @applyFilters req, @config.filters, @renderJson
            else
                @renderError 404, 'Page Not Found'

module.exports = (config) ->
    server = new Server(config)
    server.terminator()
