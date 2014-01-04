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
        menus:
            label:
                href: -> @url

    listeners:
        configure: (config) ->
            config.menus = []

        afterConfigure: (config, routes) ->
            # Update and store the menu structure
            console.log config.menus
            _.each config.menus, (menu) ->
                route = routes[menu.route]
                _.merge menu,
                    url: route(menu.params)
                    label: menu.label || inflect.titleize(menu.route)
            console.log config.menus

        htmlLocals: (config, locals) ->
            locals.menus = config.menus
