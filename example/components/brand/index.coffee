module.exports =
    name: 'brand'

    directives:
        links: label: href: -> @url

    # Jade templates to be appended to the #headers div
    headers: [
        '''
        #brand
            img#logo(src='/brand/images/logo.jpg')
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
        [ {}, (done) ->
            @setLocal
                links: [
                    { url: '/info', label: 'Info' }
                ]
                byline: 'A brand, yo'
            done()
        ]
        [ 'get info', ->
            @render 'brand/info'
        ]
    ]
