module Ruckus

    # A vector of count elements of the same class, as in
    # [elt0] [elt1] ... [eltN]
    class Vector < Parsel

        # Options include:
        # * <tt>:class</tt> the class of each element
        # * <tt>:e_opts</tt> opts to pass when creating each element (:name is always deleted)
        # * <tt>:count</tt> the number of elements of class :class in the vector. Can be a reference to another field
        # via :from_field
        def initialize(opts={})
            opts[:count] = 0x1fffffff if opts[:count] == :unlimited # grotesque hack XXX

            opts[:e_opts] ||= {}
            raise "need a class" if not opts[:class]
            super(opts)
            @value = Blob.new
            @value.parent = self
        end

        def capture(str)
            # debugger
            count = resolve(@count)
            raise "You need to provide a :count value to parse a vector; did you give it ':size' by mistake?" if not count

            count.downto(1) do |i|
                break if not str or str.empty?
                o = @class.new(@e_opts.merge(:parent => self))
                str = o.capture(str)
                @value << o
            end
            @count = @value.count
            str
        end

        def to_s(off=nil)
            @rendered_offset = off || 0
            (@value)? @value.to_s(off) : ""
        end

    end

end
