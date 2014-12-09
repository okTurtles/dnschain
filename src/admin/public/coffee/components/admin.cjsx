# @cjsx React.DOM

React = require 'react'
Router = require 'react-router'
Settings = require './settings.cjsx'
Stats = require './stats.cjsx'
Alert = require './alert.cjsx'

{ Route, Link, Redirect, RouteHandler } = Router;

module.exports = Admin = React.createClass
    getInitialState: ->
        return {}

    showError: (text) ->
        @alert.showError(text)

    showSuccess: (text) ->
        @alert.showSuccess(text)

    render: ->
        <div>
            <div className='nav-tabs'>
                <Link to="stats" className='nav-tab' data-tab='stats' ref='statsTab'>
                    <span className='icon icon-stats'></span>
                    <span>Stats</span>
                </Link>
                <Link to='settings' className='nav-tab' data-tab='settings' ref='settingsTab'>
                    <span className='icon icon-settings'></span>
                    <span>Settings</span>
                </Link>
            </div>
            <RouteHandler showError={@showError} showSuccess={@showSuccess}/>
        </div>

    componentDidMount: ->
        div = document.createElement 'div'
        document.body.appendChild div
        alert = React.createElement Alert
        @alert = React.render alert, div


routes = (
  <Route path='/' handler={Admin}>
    <Route name='stats' handler={Stats}/>
    <Route name='settings' handler={Settings}/>
    <Redirect from='/' to='stats' />
  </Route>
)

Router.run routes, (Handler) ->
  React.render(<Handler/>, document.querySelector('.admin-container'));

