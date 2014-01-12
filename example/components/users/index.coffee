_ = require('lodash')


userDirective =
    username:
            href: ->
                '/users/' + @username

module.exports =
    name: 'users'
    directives:
        users: userDirective
        user: userDirective
    routes: [
        { name: 'users', url: '/users' }
        { name: 'user', url: '/users/{username}' }
    ]
    menus: [
        { route: 'users' }
    ]
    resources:
        users: (set) ->
            @call set, [{
                username: 'datashaman'
                firstName: 'Marlin'
                lastName: 'Forbes'
            }, {
                username: 'slartibartfast'
                firstName: 'Slarti'
                lastName: 'BartFast'
            }]
        user: (set) ->
            @get 'users', (users) ->
                user = _.find(users, (user) => @req.params.username == user.username)
                @call set, user

    filters: [
        [ 'get users', ->
            @get 'users', (users) ->
                @render 'users/users', { title: 'Users', users: users }
        ]
        [ 'get user', ->
            @get 'user', (user) ->
                @render 'users/user', { title: 'User ' + user.username, user: user }
        ]
    ]
