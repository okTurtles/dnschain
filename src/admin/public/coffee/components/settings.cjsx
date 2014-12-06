# @cjsx React.DOM

React = require 'react'
settings = require '../services/settings.coffee'

module.exports = Settings = React.createClass
    getInitialState: ->
        return config: null, path: null, constants: null

    saveConfig: (event) ->
        # To stop page reload
        event.preventDefault()

        submitBtn = @refs.submit.getDOMNode()
        submitBtn.classList.add 'loading'

        settings.saveConfig @state.config, (err, data) =>
            submitBtn.classList.remove 'loading'
            if err?
                @props.showError 'Error: '+ err
            else
                @setState path: data
                @props.showSuccess "Saved to #{data}"

    handleDNSChange: (event) ->
        select = event.target
        @state.config['dns']['oldDNSMethod'] = select.options[select.selectedIndex].text

    handleChange: (key, value) ->
        keys =  key.split ':'
        index = 0
        # find the property on the config and set it's value
        set = (config, key) =>
            if index is keys.length - 1
                config[key] = value
                @setState config: @state.config
            else
                set config[key], keys[++index]

        set @state.config, keys[0]

    componentDidMount: ->
        # Get constants, path and config
        settings.getConfig (err, data) =>
            unless err?
                @setState config: data.config, path: data.path, constants: data.constants
            else
                @props.showError 'Error: ' + err

    render: ->
        config = @state.config
        path = @state.path
        constants = @state.constants
        items = []
        list = []
        subList = []

        # Return an input field based on the value type
        createInput = (valueLink) ->
            if typeof valueLink.value is 'boolean' or valueLink.value is 'true' or valueLink.value is 'false'
                return (<select valueLink={valueLink}>
                            <option>true</option>
                            <option>false</option>
                        </select>)
            else
                return <input type='text' valueLink={valueLink}/>

        createItemList = (config, pkey, sub) =>
            # If single key-value pair
            if typeof config is 'string'
                valueLink =
                        value: config,
                        requestChange: @handleChange.bind @, pkey

                input = createInput valueLink
                list.push <div key={'item-'+0} className='settings-item-input'>
                                {input}
                          </div>

            # If multi key-value pair
            else
                Object.keys(config).forEach (key, index) =>
                    valueLink =
                        value: config[key],
                        requestChange: @handleChange.bind @, pkey + ':' + key

                    if key is 'oldDNSMethod'
                        options = []
                        config[key] = Object.keys(constants['oldDNS'])[config[key]]

                        Object.keys(constants['oldDNS']).forEach (key, cindex) ->
                            options.push <option key={'option-' + cindex}>{key}</option>

                        list.push <div key={'item-'+index} className='settings-item-input'>
                                        <label>{key}</label>
                                        <select onChange={@handleDNSChange} defaultValue={config[key]}>
                                            {options}
                                        </select>
                                  </div>

                    # Handle nested objects. create sub-category.
                    else if typeof config[key] is 'object'
                        subList = []
                        createItemList config[key], pkey + ':' + key, true
                        list.push <div key={'item-'+ index} className='setting-sub-item'>
                                        <div className='settings-item-sub-hdr'>{key}</div>
                                        <div className='setting-item-sub-content'>
                                            {subList}
                                        </div>
                                  </div>
                    else
                        input = createInput valueLink
                        if sub
                            subList.push <div key={'sub-item-'+ index} className='settings-item-input'>
                                <label>{key}</label>
                                {input}
                            </div>
                        else
                            list.push <div key={'item-'+index} className='settings-item-input'>
                                            <label>{key}</label>
                                            {input}
                                       </div>

        # append path first
        if path?
            items.push <li key={'path-' + 0} className='settings-item'>
                            <div className='settings-item-hdr'>
                                Path
                             </div>
                            <div className='settings-item-content'>
                                <input className='path-input' readOnly type='text' value={path}/>
                            </div>
                        </li>

        if config?
            Object.keys(config).forEach (key, index)->
                list = []
                createItemList config[key], key
                items.push <li key={'settings-' + index} className='settings-item'>
                                <div className='settings-item-hdr'>
                                    {key}
                                </div>
                                <div className='settings-item-content'>
                                    {list}
                                </div>
                            </li>

        <div className='settings-tab tab'>
            <form className="settings-form" onSubmit={this.saveConfig}>
                <ul className="settings-list">
                    {if not config then <div className="loader"></div> else ''}
                    {items}
                </ul>
                <input className='settings-save-btn' type='submit' value='Save settings' ref='submit'/>
            </form>
        </div>