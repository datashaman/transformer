_ = require('lodash')


users = [{
    username: 'datashaman'
    firstName: 'Marlin'
    lastName: 'Forbes'
}, {
    username: 'slartibartfast'
    firstName: 'Slarti'
    lastName: 'BartFast'
}]

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
    filters: [
        [ 'users', (req) ->
            title: 'Users'
            users: users
            _view: 'users'
        ]
        [ 'user', (req) ->
            user = _.find(users, (user) -> req.params.username == user.username)
            user: user
            title: 'User ' + user.username
            _view: 'user'
        ]
    ]
