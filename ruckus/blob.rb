# === Blobs are collections of Parsels.

class IncompleteCapture < RuntimeError; end

module Ruckus
    # A Blob wraps an array. Everything within the array is rendered
    # sequentially, returning a single string. Blob rendering is effectively
    # preorder tree traversal (Blobs can contain any Parsel, including other
    # Blobs)
    class Blob < Parsel
        # No special options needed.
        #
        def initialize(opts={})
            @value = Array.new
            (opts[:populate]||[]).each do |k|
                self << k.new
            end
            super(opts)
        end

        # This is the only
        # way you should add elements to a Blob for now.
        #
        def <<(v)
            @value << v
            v.parent = self
        end

        # How many elements are in the blob? (<tt>size</tt> returns
        # the rendered size)
        #
        def count; @value.size; end

        # Assign a value to an element of a blob, so if you assign
        # blob[1] = 1, it works as expected.
        #
        def []=(k, v)
            return @value[k].value = v if not v.kind_of? Parsel
            @value[k] = v
        end

        # Where is <tt>o</tt> in this blob? (Pretty sure you could
        # just use <tt>index</tt> for this, but whatever)
        #
        def place(o)
            @value.each_with_index do |it, i|
                if o == it
                    return i
                end
            end
            nil
        end

        # As with Parsel; this will recurse through any embedded
        # blobs.
        #
        def capture(str)
            @value.each_with_index do |it, i|
                err = "at item #{ i }"
                err << " named \"#{ it.name }\"" if it.name
                err << " in struct \"#{ it.parent_struct.name }\"" if it.parent_struct

                raise IncompleteCapture.new(err) if not str or str.empty?

                # you don't always know the type of object
                # you want to instantiate at compile time;
                # it can depend on the contents of a packet.
                # when it does, there's a flag set that enables
                # a "factory" method which does the parse.
                #
                # the downside of this is once a blob has
                # been parsed with a factory, its definition
                # changes; that same blob can't be reused
                # to parse another packet. So, just don't
                # do that.

                if it.class.factory?
                    @value[i], str = it.class.factory(str)
                else
                    str = it.capture(str)
                end
            end
            str
        end

        # How big in bytes is this blob and everything it contains?
        # An empty blob has size 0
        #
        def size
            @value.inject(0) {|acc, it| acc + it.size}
        end

        # Render the blob, or return "" if it's empty.
        #
        def to_s(off=nil)
            @rendered_offset = off || 0
            voff = @rendered_offset
            r = ""
            @value.each do |it|
                s, voff = it.to_s(voff)
                r << s
            end

            if off
                return r, voff
            else
                return r
            end
        end
    end
end
