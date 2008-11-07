# === IP addresses are integers with special assignment
# You can use a Ruckus::Number as an IP address (or an IPv6
# address, if you make it 128 bits wide), but Ruckus::IP
# converts from dotted-quad strings (and, I guess if I wanted,
# DNS hostnames)
#
module Ruckus
    class IP < Parsel
        def initialize(opts={})
            opts[:value] ||= 0
            super(opts)
        end

        def to_s(off=nil)
            @rendered_offset = off || 0

            val = resolve(@value)
            val = IPAddr.inet_addr(val) if val.kind_of? String
            r = [val].pack("I")
            r = r.reverse if self.class.endian? == :little

            if off
                return r, off + 4
            else
                return r
            end
        end

        def capture(str)
            cap = str.shift 4
            sel = self.class.endian? == :little ? :reverse : :to_s
            @value = cap.send(sel).unpack("I").first
            return str
        end

        def size; 4; end
    end
end
