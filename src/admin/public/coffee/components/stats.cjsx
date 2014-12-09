# @cjsx React.DOM

React = require 'react'
ChartistGraph = require 'react-chartist'

module.exports = Stats = React.createClass
    render: ->
        # dummy data
        simpleLineChartData =
            labels: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
            series: [
                [12, 9, 7, 8, 5],
                [2, 1, 3.5, 7, 3],
                [1, 3, 4, 5, 6]
            ]
        <div className='stats-tab tab'>
            <div className='chart-container'>
                <ChartistGraph data={simpleLineChartData} type={'Line'} />
            </div>
            <div className='stats-placeholder'>DNSChain stats will go here. Above is a dummy chart.</div>
        </div>
