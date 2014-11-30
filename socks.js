var net = require('net'),
    util = require('util'),
    DNS = require('dns'),
    log = function(){},///console.log,
    ///log = console.log,
    ///info = console.info,
    info = function(){},///console.log,
    errorLog = console.error,
    clients = [],
    SOCKS_VERSION5 = 5,
    SOCKS_VERSION4 = 4,
/*
 * Authentication methods
 ************************
 * o  X'00' NO AUTHENTICATION REQUIRED
 * o  X'01' GSSAPI
 * o  X'02' USERNAME/PASSWORD
 * o  X'03' to X'7F' IANA ASSIGNED
 * o  X'80' to X'FE' RESERVED FOR PRIVATE METHODS
 * o  X'FF' NO ACCEPTABLE METHODS
 */
    AUTHENTICATION = {
        NOAUTH: 0x00,
        GSSAPI: 0x01,
        USERPASS: 0x02,
        NONE: 0xFF
    },
/*
 * o  CMD
 *    o  CONNECT X'01'
 *    o  BIND X'02'
 *    o  UDP ASSOCIATE X'03'
 */
    REQUEST_CMD = {
        CONNECT: 0x01,
        BIND: 0x02,
        UDP_ASSOCIATE: 0x03
    },
/*
 * o  ATYP   address type of following address
 *    o  IP V4 address: X'01'
 *    o  DOMAINNAME: X'03'
 *    o  IP V6 address: X'04'
 */
    ATYP = {
        IP_V4: 0x01,
        DNS: 0x03,
        IP_V6: 0x04
    },
    Address = {
        read: function (buffer, offset) {
                  if (buffer[offset] == ATYP.IP_V4) {
                      return util.format('%s.%s.%s.%s', buffer[offset+1], buffer[offset+2], buffer[offset+3], buffer[offset+4]);
                  } else if (buffer[offset] == ATYP.DNS) {
                      return buffer.toString('utf8', offset+2, offset+2+buffer[offset+1]);
                  } else if (buffer[offset] == ATYP.IP_V6) {
                      return buffer.slice(buffer[offset+1], buffer[offset+1+16]);
                  }
              },
        sizeOf: function(buffer, offset) {
                    if (buffer[offset] == ATYP.IP_V4) {
                        return 4;
                    } else if (buffer[offset] == ATYP.DNS) {
                        return buffer[offset+1];
                    } else if (buffer[offset] == ATYP.IP_V6) {
                        return 16;
                    }
                }
    };

function createSocksServer(cb) {
    var socksServer = net.createServer();
    socksServer.on('listening', function() {
        var address = socksServer.address();
        info('LISTENING %s:%d', address.address, address.port);
    });
    socksServer.on('connection', function(socket) {
        info('CONNECTED %s:%d', socket.remoteAddress, socket.remotePort);
        initSocksConnection.bind(socket)(cb);
    });
    return socksServer;
}

// socket is available as this
function initSocksConnection(on_accept) {
    // keep log of connected clients
    clients.push(this);

    // remove from clients on disconnect
    this.on('end', function() {
        var idx = clients.indexOf(this);
        if (idx != -1) {
            clients.splice(idx, 1);
        }
    });
    this.on('error', function(e) {
        errorLog('%j', e);
    });

    // do a handshake
    this.handshake = handshake.bind(this);
    this.on_accept = on_accept; // No bind. We want 'this' to be the server, like it would be for net.createServer
    this.once('data', this.handshake);
}

function handshake(chunk) {
    // SOCKS Version 4/5 is the only support version
    if (chunk[0] == SOCKS_VERSION5) {
        this.socksVersion = SOCKS_VERSION5;
        this.handshake5 = handshake5.bind(this);
        this.handshake5(chunk);
    } else if (chunk[0] == SOCKS_VERSION4) {
        this.socksVersion = SOCKS_VERSION4;
        this.handshake4 = handshake4.bind(this);
        this.handshake4(chunk);
    } else {
        errorLog('handshake: wrong socks version: %d', chunk[0]);
        this.end();
    }
}

// SOCKS5
function handshake5(chunk) {
    var method_count = 0;

    // SOCKS Version 5 is the only support version
    if (chunk[0] != SOCKS_VERSION5) {
        errorLog('socks5 handshake: wrong socks version: %d', chunk[0]);
        this.end();
    }
    // Number of authentication methods
    method_count = chunk[1];

    this.auth_methods = [];
    // i starts on 1, since we've read chunk 0 & 1 already
    for (var i=2; i < method_count + 2; i++) {
        this.auth_methods.push(chunk[i]);
    }
    log('Supported auth methods: %j', this.auth_methods);

    var resp = new Buffer(2);
    resp[0] = 0x05;
    if (this.auth_methods.indexOf(AUTHENTICATION.NOAUTH) > -1) {
        log('Handing off to handleRequest');
        this.handleRequest = handleRequest.bind(this);
        this.once('data', this.handleRequest);
        resp[1] = AUTHENTICATION.NOAUTH;
        this.write(resp);
    } else {
        errorLog('Unsuported authentication method -- disconnecting');
        resp[1] = 0xFF;
        this.end(resp);
    }
}

// SOCKS4/4a
function handshake4(chunk) {
    var cmd=chunk[1],
        address,
        port,
        uid;

    // Wrong version!
    if (chunk[0] !== SOCKS_VERSION4) {
        this.end('%d%d', 0x00, 0x5b);
        errorLog('socks4 handleRequest: wrong socks version: %d', chunk[0]);
        return;
    }
    port = chunk.readUInt16BE(2);

    // SOCKS4a
    if ((chunk[4] == 0 && chunk[5] == chunk[6] == 0) && (chunk[7] != 0)) {
        var it = 0;

        uid = '';
        for (it=0; it < 1024; it++) {
            uid += chunk[8+it];
            if (chunk[8+it] == 0x00)
                break;
        }
        address = '';
        if (chunk[8+it] == 0x00) {
            for (it++; it < 2048; it++) {
                address += chunk[8+it];
                if (chunk[8+it] == 0x00)
                    break;
            }
        }
        if (chunk[8+it] == 0x00) {
            // DNS lookup
            DNS.lookup(address, function(err, ip, family){
	            if (err) {
	                errorLog(err+',socks4a dns lookup failed');

	                this.end('%d%d', 0x00, 0x5b);
				    return;
	            } else {
				    this.socksAddress = ip;
				    this.socksPort = port;
				    this.socksUid = uid;

				    log('socks4a Request: type: %d -- to: %s:%d:%s', cmd, address, port, uid);

				    if (cmd == REQUEST_CMD.CONNECT) {
				        this.request = chunk;
				        this.on_accept(this, port, ip, proxyReady4.bind(this));
				    } else {
				        this.end('%d%d', 0x00, 0x5b);
				        return;
				    }
	            }
	        });
        } else {
            this.end('%d%d', 0x00, 0x5b);
            return;
        }
    } else {
        // SOCKS4
        address = util.format('%s.%s.%s.%s', chunk[4], chunk[5], chunk[6], chunk[7]);

        uid = '';
        for (it=0; it < 1024; it++) {
            uid += chunk[8+it];
            if (chunk[8+it] == 0x00)
                break;
        }

	    this.socksAddress = address;
	    this.socksPort = port;
	    this.socksUid = uid;

	    log('socks4 Request: type: %d -- to: %s:%d:%s', cmd, address, port, uid);

	    if (cmd == REQUEST_CMD.CONNECT) {
	        this.request = chunk;
	        this.on_accept(this, port, address, proxyReady4.bind(this));
	    } else {
	        this.end('%d%d', 0x00, 0x5b);
	        return;
	    }
    }
}

function handleRequest(chunk) {
    var cmd=chunk[1],
        address,
        port,
        offset=3;
    // Wrong version!
    if (chunk[0] !== SOCKS_VERSION5) {
        this.end('%d%d', 0x05, 0x01);
        errorLog('socks5 handleRequest: wrong socks version: %d', chunk[0]);
        return;
    } /* else if (chunk[2] == 0x00) {
        this.end(util.format('%d%d', 0x05, 0x01));
        errorLog('socks5 handleRequest: Mangled request. Reserved field is not null: %d', chunk[offset]);
        return;
    } */
    try {
	    address = Address.read(chunk, 3);
	    offset = 4 + Address.sizeOf(chunk, 3);
	    port = chunk.readUInt16BE(offset);
    } catch (e) {
        errorLog('socks5 handleRequest: Address.read '+e);
        return;
    }

    log('socks5 Request: type: %d -- to: %s:%d', chunk[1], address, port);

    if (cmd == REQUEST_CMD.CONNECT) {
        this.request = chunk;
        this.on_accept(this, port, address, proxyReady5.bind(this));
    } else {
        this.end('%d%d', 0x05, 0x01);
        return;
    }
}

function proxyReady5() {
    log('Indicating to the client that the proxy is ready');
    // creating response
    var resp = new Buffer(this.request.length);
    this.request.copy(resp);
    // rewrite response header
    resp[0] = SOCKS_VERSION5;
    resp[1] = 0x00;
    resp[2] = 0x00;

    this.write(resp);

    log('socks5 Connected to: %s:%d', Address.read(resp, 3), resp.readUInt16BE(resp.length - 2));
}

function proxyReady4() {
    log('Indicating to the client that the proxy is ready');
    // creating response
    var resp = new Buffer(8);

    // write response header
    resp[0] = 0x00;
    resp[1] = 0x5a;

    // port
    resp.writeUInt16BE(this.socksPort, 2);

    // ip
    var ips = this.socksAddress.split('.');
    resp.writeUInt8(parseInt(ips[0]), 4);
    resp.writeUInt8(parseInt(ips[1]), 5);
    resp.writeUInt8(parseInt(ips[2]), 6);
    resp.writeUInt8(parseInt(ips[3]), 7);

    this.write(resp);

    log('socks4 Connected to: %s:%d:%s', this.socksAddress, this.socksPort, this.socksUid);
}

module.exports = {
    createServer: createSocksServer
};
