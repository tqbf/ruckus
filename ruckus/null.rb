module Ruckus
    class Null < Parsel
        def initialize(opts={})
            super(opts)
        end

        def to_s(off=nil)
            @rendered_offset = off || 0
            if off
                return "", off
            else
                return ""
            end
        end

        def capture(str)
            return str
        end

        def size
            0
        end
    end
end
