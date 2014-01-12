module.exports =
    name: 'home'
    routes: [
        { name: 'home', url: '/' }
    ]
    menus: [
        { route: 'home' }
    ]
    filters: [
        [ 'get home', ->
            @render 'home/home', { title: 'Home' }
        ]
    ]
