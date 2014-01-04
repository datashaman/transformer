# Functional goodness
_ = require('lodash')

module.exports =
    name: 'brand'

    directives:
        links: label: href: -> @url

    # Jade templates to be appended to the #headers div
    headers: [
        '''
        #brand
            img#logo(src='/images/logo.png')
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

    filters: [
        [ {}, ->
            links: [
                { url: '/info', label: 'Info' }
            ]
            byline: 'A brand, yo'
        ]
    ]
