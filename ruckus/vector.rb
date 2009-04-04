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

            raise "need a class" if not opts[:class] and not opts[:classes_from]

            if opts[:classes_from]
                if not opts[:keys_from]
                    raise "need a module to pull keys from (protocol numbers, command IDs, whatever) as :keys_from"
                end

                begin
                    @keys = (m = opts[:keys_from]).constants.
                        select {|x| m.const_get(x).kind_of? Numeric}.
                        map {|x| [m.const_get(x), x]}.
                        to_hash
                rescue => e
                    raise "can't look up keys:\n #{ e }"
                end

                begin
                    @classes = (m = opts[:classes_from]).constants.
                        select {|x| m.const_get(x).kind_of? Class}.
                        map do |x|
                            name = (klass = m.const_get(x)).
                                     to_s.
                                     underscore.
                                     upcase
                            name = name[name.rindex(":")+1..-1]
                            [ name, klass ]
                        end.to_hash
                rescue => e
                    raise "can't generate class dictionary:\n #{ e }"
                end

                raise "need a :key_field or :key_finder" if not opts[:key_field] and not opts[:key_finder]
            end

            super(opts)
            @value = Blob.new
            @value.parent = self
        end

        def capture(str)
            count = resolve(@count)
            if not count
                raise "You need to provide a :count value to parse a vector; did you give it :size by mistake?"
            end

            count.downto(1) do |i|
                break if not str or str.empty?

                if @class
                    o = @class.new(@e_opts.merge(:parent => self))
                    str = o.capture(str)
                    @value << o
                else
                    if @key_field
                        key = parent_struct.send(@key_field)
                    end

                    if @key_finder
                        key = @key_finder.call(str)
                    end

                    begin
                        o = @classes[@keys[key]].new(@e_opts.merge(:parent => self))
                        str = o.capture(str)
                        @value << o
                    rescue => e
                        raise "couldn't create an object from key:\n#{ e }"
                    end
                end
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
