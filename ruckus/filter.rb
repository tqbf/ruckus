module Ruckus
    class Filter < Parsel
        def initialize(val, &block)
            raise "need a block" if not block_given?
            val = val.clone
            val.parent = self
            opts = { :value => val }
            @block = block
            super(opts)
        end

        def to_s
            @block.call(@value.to_s)
        end
    end
end
