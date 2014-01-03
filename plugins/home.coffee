module.exports =
    name: 'home'
    routes: [
        { name: 'home', url: '/' }
    ]
    menus: [
        { route: 'home' }
    ]
    directives:
        menus:
            label:
                href: ->
                    @url
    filters: [
        [ 'home', (req) ->
            title: 'Home'
            _view: 'home'
        ]
    ]
