# === Choices pick binary structures at runtime

module Ruckus

    # A choice wraps a blob, and, on input, picks what to put in the blob
    # based on a code block. Use choices to dispatch protocol responses
    # based on type codes, etc.
    #
    class Choice < Parsel

        # You must call Choice.new with a block that takes two
        # arguments --- an input string and a reference to the
        # choice instance. For instance:
        #
        #   data << Choice.new do |buf, this|
        #            if this.parent_struct.message_code == Codes::ERROR
        #                this << ErrorFrame.new
        #            else
        #                this << ResponseFrame.new
        #            end
        #            this[-1].capture(buf)
        #        end
        #
        def initialize(opts={}, &block)
            @parent = opts[:parent]
            raise "provide a block" if not block_given? and not opts[:block] and not respond_to? :choose
            if not opts[:block] and not block_given?
                opts[:block] = lambda {|x, y| self.choose(x)}
            end
            super(opts)
            @block ||= block
            @value = Blob.new
            @value.parent = self
        end

        # Just render the blob
        #
        def to_s(off=nil)
            @rendered_offset = off || 0
            (@value)? @value.to_s(off) : ""
        end

        # Call the block, which must return the remainder string.
        #
        def capture(str)
            block.call(str, self)
        end

        def <<(o)
            @value << o
            o.parent = self
        end
    end
end

