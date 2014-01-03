module.exports =
    name: 'contact'
    menus: [
        { name: 'contact', url: '/contact-us' }
        { name: 'contacts', url: '/contacts' }
    ]
    routes: [
        { name: 'contact', url: '/contact-us' }
        { name: 'contacts', url: '/contacts' }
    ]
    filters: [
        [ 'contacts', (req) ->
            # req.session.contacts = []
            contacts: req.session.contacts
        ]
        [ 'contact', (req) ->
            _view: 'contact'
        ]
        [{
            method: 'POST'
            route:
                name: 'contact'
        }, (req, res) ->
            req.session.contacts.push req.body

            res.statusCode = 302
            res.setHeader('Location', '/contacts')
            res.end('Redirecting...')
        ]
    ]
