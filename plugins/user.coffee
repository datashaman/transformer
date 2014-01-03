users = [{
    username: 'datashaman'
    firstName: 'Marlin'
    lastName: 'Forbes'
}, {
    username: 'slartibartfast'
    firstName: 'Slarti'
    lastName: 'BartFast'
}]

directives =
    user:
        username:
            href: ->
                '/users/' + @username

module.exports =
    name: 'user'
    directives: directives
    routes: [
        { name: 'users', url: '/users' }
        { name: 'user', url: '/users/{username}' }
    ]
    menus: [
        { route: 'users' }
    ]
    filters: [
        [ 'users', (req) ->
            req.directives.users = directives.user

            title: 'Users'
            users: users
            _view: 'users'
        ]
        [ 'user', (req) ->
            req.directives.user = directives.user

            for user in users
                if req.params.username is user.username
                    found = user
                    break

            user: found
            title: 'User ' + user.username
            _view: 'user'
        ]
    ]
