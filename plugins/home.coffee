module.exports =
    name: 'home'
    routes: [
        { name: 'home', url: '/' }
    ]
    menus: [
        { name: 'home', url: '/' }
    ]
    directives:
        menus:
            name:
                href: ->
                    @url
    filters: [
        [ 'home', (req) ->
            title: 'Home'
            _view: 'home'
        ]
    ]
