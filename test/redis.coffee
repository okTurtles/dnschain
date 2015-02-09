# Test using mocha.

assert = require 'assert'
should = require 'should'
Promise = require 'bluebird'
_ = require 'lodash-contrib'
execAsync = Promise.promisify require('child_process').exec
{dnschain: {DNSChain, globals: {gConf}}} = require './support/env'
{TimeoutError} = Promise


describe 'Redis DNS cache', ->

    # time how long it takes to do a bunch of DNS requests
    it 'should measure non-redis DNS performance', ->

    # time how long it takes to do a bunch of DNS requests
    it 'should measure how long it takes to repeat queries with redis disabled', ->

    # make the same queries now 
    it 'should be significantly faster to repeat queries with redis enabled', ->

describe 'Redis HTTP API cache', ->

    # time how long it takes to do a bunch of DNS requests
    it 'should measure non-redis HTTP API performance', ->

    # time how long it takes to do a bunch of DNS requests
    it 'should measure how long it takes to repeat queries with redis disabled', ->

    # make the same queries now 
    it 'should be significantly faster to repeat queries with redis enabled', ->

