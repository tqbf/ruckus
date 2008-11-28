# === Parsels are tree nodes

module Ruckus
    # A parsel is an object that supports the following three methods:
    # * An <tt>initialize</tt> that accepts and passes through an opts hash
    # * A <tt>to_s<tt> that renders binary, and takes an optional "offset" arg
    # * A <tt>capture</tt> that parses a binary string and returns whatever
    #   is left of the strin.
    #
    # You assemble a tree of Parsel objects to make a packet. The parsel
    # tree winds up looking a lot like the HTML DOM:
    # * There's a tree root you can get to from anywhere by calling <tt>root</tt>
    # * Nodes can have DOM-style "classes" (we call them "names")
    # * Nodes can have DOM-style "ids" (we call them "tags")
    #
    # As the tree is rendered (by calling to_s on every node), the offset
    # in the final string is stored in @rendered_offset.
    #
    # All this is useful for instance with binary formats that required padded
    # offsets from headers --- tag the header base, look it up from anywhere,
    # compare rendered offsets, and you know how much padding you need.
    #
    # Any attribute of a Parsel can be replaced with:
    # * A method to call on a sibling node to get the value (for instance,
    #   the size of a string)
    # * A complex specification of which node to query, what method to use,
    #   and how to modify it
    # * A block
    #
    class Parsel
        attr_accessor :value
        attr_accessor :parent
        attr_accessor :rendered_offset
        attr_accessor :tag
        attr_accessor :name
        attr_accessor :rendering

        # Is this parsel in native byte order?
        #
        def native?
            self.class.native @endian || :little
        end

        # What's our native endianness? :big or :little
        #
        def self.endian?
            @endianness ||= ([1].pack("I")[0] == 1 ? :little : :big)
        end

        # Is this endianness native?
        #
        def self.native?(endian)
            endian? == endian
        end

        # How many bytes, rounded up, does it take to represent this
        # many bits?
        #
        def self.bytes_for_bits(b)
            (b / 8) + ((b % 8) != 0 ? 1 : 0)
        end

        # Coerce native types to their equivalent parsels, so you can
        # assign "1" to a Number field, etc
        #
        def self.coerce(val)
            if val.kind_of? Numeric
                Number.new :value => val
            elsif val.kind_of? String
                Str.new :value => val
            end
        end

        # Read Blob first.
        #
        # Parsels can have nonscalar values, including blocks and
        # references to the values of other fields. This is a bit
        # of a mess. Takes:
        #
        # all::     Rebind all instance variables, not just @value
        # meth::    Method to call on target object to extract value,
        #           but note that you can just pass "val" as a sym
        #           for same effect. (Default: :size)
        # source::  Source Parsel to extract object, but you'll never
        #           specify this directly.
        #           One exception: :source => :rest means, "apply the
        #           method to all subsequent elements of the blob or
        #           structure"
        # offset::  (Default: 1) which neighboring Parsel should we
        #           extract from --- can also be <tt>:this</tt>,
        #           <tt>:prev</tt>, and <tt>:next</tt>.
        # block::   A Proc to call with the object we're extracting.
        #
        def resolve(val)
            return nil if not val
            return val if [String, Integer, Ruckus::Mutator::Mutator].kind_of_these? val
            return val if val == true
            return val if val == false

            o = {}

            if val.kind_of? Symbol
                o[:meth] = val
            elsif val.kind_of? Hash
                o = o.merge(val)
            end

            if (t = @from_tag) || (t = o[:from_tag])
                o[:source] = root.find_tag(t)
                raise "can't find" if not o[:source]
            end

            if (f = @from_field) || (f = o[:from_field])
                o[:source] = parent_struct.send f
                raise "can't find field" if not o[:source]
            end

            place = parent.place(self)

            if not o[:source]
                raise "unparented" if not parent

                o[:offset] ||= 1
                o[:offset] = 0 if o[:offset] == :this
                o[:offset] = -1 if o[:offset] == :prev
                o[:offset] = 1 if o[:offset] == :next

                loc = place + o[:offset]
                o[:source] = parent[loc]

                raise "can't resolve #{ o } for #{ @name }" if not o[:source]
            end

            if not o[:block]
                o[:meth] ||= :size

                if o[:source] == :rest
                    r = 0
                    ((place+1)..(parent.size)).each do |i|
                        r += parent[i].send(o[:meth]) if parent[i]
                    end
                else
                    r = o[:source].send o[:meth]
                end
            else
                r = o[:block].call o[:source]
            end

            # cheat: if resolution returns a symbol --- which happens
            # with len/string pairs, because they depend on each other ---
            # return nil. This effectively unbounds the string during to_s.
            r = nil if r.kind_of? Symbol

            r = @modifier.call(self, r) if @modifier
            return r
        end

        # Get to the next node (at this level of the tree --- does
        # not traverse back through parent)
        #
        def next
            parent[parent.place(self) + 1]
        end

        # Opposite of Parsel#next
        #
        def prev
            parent[parent.place(self) - 1]
        end

        # Walk up the parents of this node until we find a containing
        # structure.
        #
        def parent_structure(p = self)
            while p.parent
                p = p.parent
                break if p.kind_of? Ruckus::Structure
            end
            return p
        end
        alias_method :parent_struct, :parent_structure

        VERBOTEN = [:size, :capture]

        # Note: all opts become instance variables. Never created
        # directly.
        #
        def initialize(opts={})
            (rec = lambda do |k|
                begin
                    k.const_get(:OPTIONS).each do |key, v|
                        opts[key] ||= v
                    end
                rescue
                ensure
                    rec.call(k.superclass) if k.inherits_from? Parsel
                end
            end).call(self.class)

            opts.each do |k, v|
                next if VERBOTEN.member? k

                instance_variable_set "@#{ k }".intern, v
                (class << self; self; end).instance_eval {
                    attr_accessor k
                }
            end

            capture(opts[:capture]) if opts[:capture]
        end

        # How big is the rendered output in bytes? By default,
        # the worst possible impl: render and take size of result.
        # You can override to make this more reasonable.
        #
        def size
            return nil if not @value
            return to_s.size
        end

        # Parsel decorates native types.
        #
        def method_missing(meth, *args, &block)
            @value.send meth, *args, &block
        end

        # Traverse all the way to the root of the tree
        #
        def root(p = self, &block)
            yield p if block_given?
            while p.parent
                p = p.parent
                yield p if block_given?
            end
            return p
        end

        # Stubbed.
        #
        def fixup
        end

        # Find any node by its tag. This isn't indexed in any way, so
        # it's slow, but who cares?
        #
        def find_tag(t)
            r = nil
            if @tag == t
                r = self
            elsif
                begin
                    each do |it|
                        r = it.find_tag(t)
                        break if r
                    end
                rescue
                end
            end
            return r
        end

        # Find a node by its tag, but return its enclosing structure, not
        # the node itself. This is usually what you want; the first field
        # of a header might be tagged, but you just wanted a reference to
        # the header entire.
        #
        def find_tag_struct(t)
            p = find_tag(t)
            if(p)
                return p.parent_struct
            else
                return nil
            end
        end

        # Walk up parents until you find one of type <tt>klass</tt>;
        # so, if you have a FooHeader containing lots of FooRecords,
        # and you have a handle on a FooElement inside a FooRecord, you
        # can call <tt>x.find_containing(FooRecord)</tt> to jump right
        # back to the header.
        #
        def find_containing(klass)
            p = parent
            while p and not p.kind_of? klass
                p = p.parent
            end
            return p
        end

        # Wrap tree-traversal; <tt>&block</tt> is called for each
        # element of the tree.
        #
        def visit(&block)
            raise "need block" if not block_given?

            block.call(self)

            begin
                @value.each do |o|
                    o.visit(&block)
                end
            rescue
            end
        end

        # This kind of doesn't belong here. XXX factor out into
        # module.
        #
        # Use Parsel#visit to permute every permutable Parsel in
        # a message, by calling value.permute (Mutator objects
        # respond to this message). See Mutate.rb.
        #
        def permute(all=nil)
            visit {|o| o.permute(nil)} and return if all
            begin
                @value.permute
            rescue
            end
        end

        # See Blob.
        #
        # What's our position in the parent? This works for any
        # enumerable parent.
        #
        def where_am_i?
            return @where_am_i if @where_am_i

            raise "not parented" if not parent

            parent.each_with_index do |o, i|
                if o == self
                    @where_am_i = i
                    return i
                end
            end
            nil
        end

        # This got insane following links, so cut down what 'pp' gives you,
        # mostly by not recursively rendering children.
        #
        def inspect
            if @value.kind_of? Parsel
                val = "#<#{ @value.class }:#{ @value.object_id }: @name=\"#{ @name }\">"
            else
                val = @value.inspect
            end

            "#<#{ self.class }:#{ self.object_id }: @name=\"#{ @name }\" @value=#{ val }>"
        end

        # phase in the new names
        def out(*args); to_s(*args); end
        def in(*args); capture(*args); end

        def factory?; false; end
    end
end
