module.exports =
    name: 'home'
    routes: [
        { name: 'home', url: '/' }
    ]
    menus: [
        { route: 'home' }
    ]
    filters: [
        [ 'home', (req) ->
            title: 'Home'
            _view: 'home'
        ]
    ]
