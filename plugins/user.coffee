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
    name: 'user'
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
            for user in users
                if req.params.username is user.username
                    found = user
                    break

            user: found
            title: 'User ' + user.username
            _view: 'user'
        ]
    ]
