# @cjsx React.DOM

React = require 'react'

module.exports = Alert = React.createClass
    getInitialState: ->
        return show: false, text: @props.text or '', error: false

    showSuccess: (text) ->
        @setState show: true, text: text, error: false

    showError: (text) ->
        @setState show: true, text: text, error: true

    componentDidUpdate: ->
        clearTimeout(@timer)
        @timer = setTimeout((->
            @setState show: false
        ).bind(this), (if @state.error then 5000 else 2000))

    render: ->
        text = @state.text
        show = @state.show
        error = @state.error

        <div className={'alert '+ (if error then 'err ' else 'success ') + (if show then 'show' else 'hide')}>
            <span>{text}</span>
        </div>
