module.exports =
    name: 'brand'

    directives:
        links: label: href: -> @url

    # Jade templates to be appended to the #headers div
    headers: [
        '''
        #brand
            #byline
        '''
    ]

    # Jade templates to be appended to the #footers div
    footers: [
        '''
        ul#links
            li.link
                a.label
        '''
    ]
    routes: [
        { name: 'info', url: '/info' }
    ]
    filters: [
        [ {}, ->
            links: [
                { url: '/info', label: 'Info' }
            ]
            byline: 'A brand, yo'
        ]
        [ 'info', ->
        ]
    ]
