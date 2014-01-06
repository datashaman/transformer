module.exports =
    name: 'contacts'
    routes: [
        { name: 'contact us', url: '/contact-us' }
        { name: 'contacts', url: '/contacts' }
        { name: 'view contact', url: '/contacts/{id}' }
    ]
    menus: [
        { route: 'contact us' }
        { route: 'contacts' }
        { route: 'view contact', label: 'View Contact #1', params: { id: 1 } }
    ]
    filters: [
        [ 'contacts', (req) ->
            # req.session.contacts = []
            contacts: req.session.contacts
            _view: 'contacts'
        ]
        [ 'contact us', (req) ->
            _view: 'contact'
        ]
        [{
            method: 'POST'
            route:
                name: 'contacts'
        }, (req, res) ->
            req.session.contacts.push req.body
            @redirect res, '/contacts'
        ]
    ]
