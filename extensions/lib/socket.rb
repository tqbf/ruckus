class Socket
    module SocketExtensions
        def self.addr(host, port=nil)
            if not port
                raise "bad!" if not host =~ /(.*):(.*)/
                host = $1
                port = $2
            end
            port = port.to_i
            Socket.pack_sockaddr_in(port, host)
        end
    end
    include SocketExtensions
end
