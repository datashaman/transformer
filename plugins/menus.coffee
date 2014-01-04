# Functional goodness
_ = require('lodash')

# For generating default labels
inflect = require('inflect')

module.exports =
    name: 'menus'

    # Jade headers to be appended to the #headers div
    headers: [
        '''
        ul#menus
            li.menu
                a.label
        '''
    ]

    directives:
        menus: label: href: -> @url

    listeners:
        configure: (config) ->
            config.menus = []

        configurePlugin: (config, plugin) ->
            config.menus = config.menus.concat(plugin.menus) if plugin.menus?

        afterConfigure: (config, routes) ->
            # Generate URLs and labels for menus
            _.each config.menus, (menu) ->
                route = routes[menu.route]
                _.merge menu,
                    url: route(menu.params)
                    label: menu.label || inflect.titleize(menu.route)

        htmlLocals: (config, locals) ->
            locals.menus = config.menus
