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

    directives:
        count: text: ->
            @contacts.length + ' ' + (if @contacts.length==1 then 'contacts' else 'contacts')

    resources:
        contacts: (set) ->
            @call set, @session.contacts
        contact: (set) ->
            @call set, @session.contacts[0]

    filters: [
        [ 'get contacts', ->
            @get 'contacts', (contacts) ->
                @render 'contacts/contacts', { contacts: contacts }
        ]
        [ 'get contact us', ->
            @render 'contacts/contact'
        ]
        [ 'view contact', ->
            @get 'contact', (contact) ->
                @render 'contacts/contact', { contact: contact }
        ]
        [ 'post contacts', ->
            @get 'contacts', (contacts) ->
                contacts.push @req.body
                @redirect '/contacts'
        ]
    ]
