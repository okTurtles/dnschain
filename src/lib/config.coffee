###

dnsnmc
http://dnsnmc.net

Copyright (c) 2013 Greg Slepak
Licensed under the BSD 3-Clause license.

###

# TODO: go through 'TODO's!

'use strict'

module.exports = (dnsnmc) ->
    # expose these into our namespace
    for k of dnsnmc.globals
        eval "var #{k} = dnsnmc.globals.#{k};"
