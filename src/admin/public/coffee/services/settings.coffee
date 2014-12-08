$ = require 'jquery-browserify'

module.exports = Settings =
    getConfig: (callback) ->
        $.ajax
          url: '/config',
          dataType: 'json',
          success: (data) ->
            callback null, data
          error: ->
            callback 'Unable to connect.'

    saveConfig: (data, callback) ->
        $.ajax
            type: 'POST',
            dataType: 'json',
            contentType : 'application/json',
            url: '/save/config',
            data: JSON.stringify(data),
            success: (data) ->
                unless data.err?
                    callback null, data.msg
                else
                    callback data.err, data.msg
            error: ->
                callback 'Unable to connect.'
