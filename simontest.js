var net = require('net'),
    socks = require('./socks.js');

// Create server
// The server accepts SOCKS connections. This particular server acts as a proxy.
console.log(process.argv[2]);
var HOST='0.0.0.0',
    PORT=process.argv[2],
    server = socks.createServer(function(socket, port, address, proxy_ready) {

      // Implement your own proxy here! Do encryption, tunnelling, whatever! Go flippin' mental!
      // I plan to tunnel everything including SSH over an HTTP tunnel. For now, though, here is the plain proxy:

      console.log('Got through the first part of the SOCKS protocol.')
      var proxy = net.createConnection(port, address, proxy_ready);

      proxy.on('error', function(err){
          console.log(err);
          console.log('Ignore proxy error', err);
      });

      socket.on('error', function(err){
          if (err.code === "EPIPE") {
            socket.destroy();
          }
          console.log('Ignore socket error', err);
      });

      socket.pipe(proxy).pipe(socket);

    });

server.on('error', function (e) {
    console.error('SERVER ERROR: %j', e);
    if (e.code == 'EADDRINUSE') {
        console.log('Address in use, retrying in 10 seconds...');
        setTimeout(function () {
            console.log('Reconnecting to %s:%s', HOST, PORT);
            server.close();
            server.listen(PORT, HOST);
        }, 10000);
    }
});
server.listen(PORT, HOST);
