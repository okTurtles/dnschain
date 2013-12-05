var rpc = require('json-rpc2'),
dns = require('dns'),
ndns = require('native-dns'),
dnsd = require('dnsd'),
http = require('http'),
url = require('url');

OURIP = '192.184.84.104';

//JSON = require('JSON');
util = require('util');

String.prototype.endsWith = function(suffix) {
    return this.indexOf(suffix, this.length - suffix.length) !== -1;
};

var client = rpc.Client.create(8336, 'localhost', 'mother', 'r9kdshfslkdfjvnowe');

var server = dnsd.createServer(function (req, res) {
    console.log('%s:%s/%s %j', req.connection.remoteAddress, req.connection.remotePort, req.connection.type, req);
    var question = res.question[0]
    , hostname = question.name
    , length = hostname.length
    , ttl = Math.floor(Math.random() * 3600)

    if(question.type != 'A') {
        console.log('not resolving type: ' + question.type)
        res.end()
    } else {
        if (hostname.endsWith('.bit')) {
            dbit = 'd/' + hostname.substring(0, hostname.length - 4);
            client.call('name_show', [dbit], function(err, result) {
                if (!err) {
                    console.log('name_show ' + dbit + ': ' + util.inspect(result));
                    var info = JSON.parse(result.value);
                    console.log('name_show ' + dbit + ' (info): ' + util.inspect(info));
                    ns = info.ns[0];
                    dns.resolve4(ns, function (err, addrs) {
                        if (err) {
                            console.log('err['+dbit+'] ' + err);
                            res.end()
                        } else {
                            console.log('lookup['+dbit+'] with' + addrs[0]);
                            var req = ndns.Request({
                                question: ndns.Question({name: hostname, type: 'A'}),
                                server: {address: addrs[0]}
                            }).on('message', function (err, answer) {
                                if (err)
                                    console.log('err['+dbit+']/message: ' + err);
                                else {
                                    console.log('got answer for '+dbit+': ' + util.inspect(answer));
                                    res.answer.push({name:hostname, type:'A', data:answer.answer[0].address, 'ttl':ttl});
                                }
                            }).on('end', function () {
                                res.end();
                            }).send();
                        }
                    });
                    //for (var k in result)
                    //    console.log(k + ': ' + result[k]);
                } else
                    console.log('getinfo [err]: ' + err);
            });
        }
        else if (hostname === 'secure.dnsnmc.net') {
            console.log('request for secure.dnsnmc.net! sending our IP: ' + OURIP);
            res.answer.push({name:hostname, type:'A', data:OURIP, 'ttl':ttl})
            res.end()
        }
        else {
            dns.resolve4(hostname, function(err, addrs) {
                if (!err)
                    res.answer.push({name:hostname, type:'A', data:addrs[0], 'ttl':ttl})
                else
                    console.log('resolve4 error: ' + err)
                res.end()
            })
        }
    }
}).listen(53, '0.0.0.0');

// Call add function on the server

http.createServer(function (req, res) {
    var path = url.parse(req.url).pathname.substr(1);
    console.log('http server got req for ' +path+': ' + util.inspect(req));
    client.call('name_show', [path], function(err, result) {
        if (err) {
            res.writeHead(404,  {'Content-Type': 'text/plain'});
            res.write('couldn\'t find : ' + path);
        } else {
            res.writeHead(200, {'Content-Type': 'application/json'});
            console.log('name_show ' + path + ': ' + util.inspect(result));
            res.write(result.value);
        }
        res.end();
    });
}).listen(8000);

//console.log(client);
console.log('listening on port 53...');
