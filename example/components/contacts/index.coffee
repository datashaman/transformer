module.exports =
    name: 'contacts'

    routes: [
        { name: 'contact us', url: '/contact-us' }
        { name: 'contacts', url: '/contacts' }
        { name: 'contact', url: '/contacts/{id}' }
    ]

    menus: [
        { route: 'contact us' }
        { route: 'contacts' }
        { route: 'contact', label: 'View Contact #1', params: { id: 1 } }
    ]

    directives:
        count: text: ->
            @contacts.length + ' contact' + 's' unless @contacts.length==1

    resources:
        contacts: (set) ->
            @session.contacts ?= []
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
        [ 'get contact', ->
            @get 'contact', (contact) ->
                @render 'contacts/contact', { contact: contact }
        ]
        [ 'post contacts', ->
            @get 'contacts', (contacts) ->
                contacts.push @req.body
                @redirect '/contacts'
        ]
    ]
