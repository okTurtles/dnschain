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

      proxy.on('data', function(d) {
        try {
          console.log('receiving ' + d.length + ' bytes from proxy');
          if (!socket.write(d)) {
              proxy.pause();

              socket.on('drain', function(){
                  proxy.resume();
              });
              setTimeout(function(){
                  proxy.resume();
              }, 100);
          }
        } catch(err) {
          console.log("Errrrrrrrrr");
        }
      });
      socket.on('data', function(d) {
        // If the application tries to send data before the proxy is ready, then that is it's own problem.
        try {
          console.log('sending ' + d.length + ' bytes to proxy');
          if (!proxy.write(d)) {
              socket.pause();

              proxy.on('drain', function(){
                  socket.resume();
              });
              setTimeout(function(){
                  socket.resume();
              }, 100);
          }
        } catch(err) {
        }
      });

      proxy.on('error', function(err){
          console.log('Ignore proxy error');
      });
      proxy.on('close', function(had_error) {
        try {
          socket.end();
          console.error('The proxy closed');
        } catch (err) {
        }
      }.bind(this));

      socket.on('error', function(err){
          if (err.code === "EPIPE") {
            socket.destroy();
          }
          console.log('Ignore socket error');
      });
      socket.on('close', function(had_error) {
        try {
          if (this.proxy !== undefined) {
            proxy.removeAllListeners('data');
            proxy.end();
          }
          console.error('The application closed');
        } catch (err) {
        }
      }.bind(this));

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

// vim: set filetype=javascript syntax=javascript :
