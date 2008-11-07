require 'ipaddr'

class IPAddr
    attr_reader :mask_addr

    # ---------------------------------------------------------

    # make an IP address take the int32 value provided

    def set_int(ip)
        set(ip, Socket::AF_INET)
    end

    # ---------------------------------------------------------

    # randomize the "host" part of the IP address (destructive)

    def random(mask=0xFFFFFFFF)
        r = rand(0xFFFFFFFF) & mask
        i = self.to_i & (~mask)
        self.set_int(i | r)
    end

    alias_method :random!, :random

    # ---------------------------------------------------------

    # convert a string to IP

    def inet_addr(str)
        in_addr(str)
    end

    # ---------------------------------------------------------

    # construct an IPAddr from a dotted quad string or integer

    def IPAddr.inet_addr(str)
        if str.kind_of? String
            IPAddr.lite(str).to_i
        else
            i = IPAddr.new(0, Socket::AF_INET)
            i.set_int(str)
            return i
        end
    end

    # ---------------------------------------------------------

    # construct an IPAddr from a dotted quad string without
    # incurring a reverse lookup.

    def IPAddr.lite(str)
        ip = IPAddr.new(0, Socket::AF_INET)

        parts = str.split "/"

        ip.set_int(ip.inet_addr(parts[0]))
        ip = ip.mask parts[1] if parts[1]
        return ip
    end

    # ---------------------------------------------------------

    # Convert 255.255.255.0 to 24

    def self.mask2mlen(mask)
        len = 0
        while len < 32 && mask & 0x80000000 != 0
            mask <<= 1
            mask &= 0xFFFFFFFF
            len += 1
        end
        return len
    end

    # ---------------------------------------------------------

    # to_s with a cidr prefix at the end

    def to_cidr_s
        "#{ to_s }/#{ self.class.mask2mlen(@mask_addr) }"
    end

    # ---------------------------------------------------------

    # get the mask length

    def to_mlen
        mask = self.to_i
        self.class.mask2mlen(mask)
    end

    # ---------------------------------------------------------

    # get the highest address in the range defined by the netmask

    def top
        IPAddr.inet_addr(self.to_i | (0xFFFFFFFF & (~self.mask_addr)))
    end

    # ---------------------------------------------------------

    # get the lowest address in the range defined by the netmask

    def bottom
        IPAddr.inet_addr(self.to_i & self.mask_addr)
    end

    # ---------------------------------------------------------

    # get a random address from within the range defined by the
    # netmask.

    def choice
        return self.clone if self.mask_addr == 0xFFFFFFFF

        span = self.top.to_i - self.bottom.to_i
        x = self.clone
        x.set_int(self.bottom.to_i + rand(span))
        return x
    end

    # ---------------------------------------------------------

    # test if the address provided is in the range defined by the
    # netmask

    def contains(i)
        if not i.kind_of? IPAddr
            i = IPAddr.inet_addr i
        end

        i.to_i >= self.bottom.to_i and i.to_i <= self.top.to_i
    end

    alias_method :contains?, :contains
end
