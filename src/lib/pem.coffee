###

dnschain
http://dnschain.org

Copyright (c) 2015 okTurtles Foundation

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

###

module.exports = (dnschain) ->
    # expose these into our namespace
    for k of dnschain.globals
        eval "var #{k} = dnschain.globals.#{k};"

    execAsync = Promise.promisify require('child_process').exec

    pem =
        certFingerprint: (cert, opts={}) ->
            opts = _.defaults opts, {timeout:1000, encoding:'utf8'}
            cmd = "openssl x509 -fingerprint -sha256 -text -noout -in \"#{cert}\""
            gLogger.debug "running: #{cmd}"
            execAsync(cmd, opts).spread (stdout, stderr) ->
                stdout.match(/SHA256 Fingerprint=([0-9A-F:]{95})$/m)[1]
            .catch (err) ->
                gErr "Failed to read public key fingerprint: #{err?.message}"

        genKeyCertPair: (key, cert, opts={}) ->
            opts = _.defaults opts, {timeout:10000, encoding:'utf8'}
            cmd = """
            openssl req -new -newkey rsa:4096 -days 730 -nodes -sha256 -x509 \
                        -subj "/CN=#{os.hostname()}" \
                        -keyout "#{key}" -out "#{cert}"
            """
            gLogger.debug "running: #{cmd}"
            execAsync(cmd, opts).spread (stdout, stderr) ->
                fs.chmodSync key, 0o600 # rw for owner, 0 for everyone else
            .catch (err) ->
                gErr "Failed to generate key material: #{err?.message}"
