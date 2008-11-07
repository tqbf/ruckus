# === A sort of half-baked DSL for defining packet fields.
# These are all classmethods of Structure.
module Ruckus
    class Structure
        # Any number, ie
        #    num :len, :width => 32, :endianness => :little
        #
        def self.num(name, opts)
            add(Number, opts.merge(:name => name))
        end

        # little-endian 16 bits (a.k.a. <tt>h16</tt>, h=host)
        def self.le16(*args); with_args(*args) {|name, opts| num name, opts.merge(:width => 16, :endian => :little )}; end
        alias_cmethod :h16, :le16
        alias_cmethod :uint16le, :le16

        # big-endian 16 bits (a.k.a. <tt>n16</tt>, n=network)
        def self.be16(*args); with_args(*args) {|name, opts| num name, opts.merge(:width => 16, :endian => :big )}; end
        alias_cmethod :n16, :be16
        alias_cmethod :uint16be, :be16

        # little 32
        def self.le32(*args); with_args(*args) {|name, opts| num name, opts.merge(:width => 32, :endian => :little )}; end
        alias_cmethod :h32, :le32
        alias_cmethod :uint32le, :le32

        # big 32
        def self.be32(*args); with_args(*args) {|name, opts| num name, opts.merge(:width => 32, :endian => :big )}; end
        alias_cmethod :n32, :be32
        alias_cmethod :uint32be, :be32

        # little 64
        def self.le64(*args); with_args(*args) {|name, opts| num name, opts.merge(:width => 64, :endian => :little )}; end
        alias_cmethod :h64, :le64
        alias_cmethod :uint64le, :le64

        # big 64
        def self.be64(*args); with_args(*args) {|name, opts| num name, opts.merge(:width => 64, :endian => :big )}; end
        alias_cmethod :n64, :be64
        alias_cmethod :uint64be, :be64

        # a single byte, a.k.a. le8, be8, n8, h8
        def self.byte(*args); with_args(*args) {|name, opts| num name, opts.merge(:width => 8)}; end
        alias_cmethod :le8, :byte
        alias_cmethod :be8, :byte
        alias_cmethod :n8,  :byte
        alias_cmethod :h8,  :byte

        def self.char(*args); with_args(*args) {|name, opts| str opts.merge(:name => name, :size => 1)}; end

        # For no good reason, "halfwords" are little endian, but "shorts" are
        # network byte order. You're welcome.
        alias_cmethod :half, :h16
        alias_cmethod :halfword, :h16
        alias_cmethod :short, :n16

        def self.decimal(*args); with_args(*args) {|name, opts| num name, opts.merge(:ascii => true, :radix => 10)}; end
        def self.hex_number(*args); with_args(*args) {|name, opts| num name, opts.merge(:ascii => true, :radix => 16)}; end

        # Yep, you can declare single bits
        def self.bit(*args); with_args(*args) {|name, opts| num name, opts.merge(:width => 1)}; end

        def self.tag_bit(*args); with_args(*args) {|name, opts| num name, opts.merge(:width => 1, :tag => name)}; end

        # Yep, you can have nibble fields
        def self.nibble(*args); with_args(*args) {|name, opts| num name, opts.merge(:width => 4)}; end
        alias_cmethod :nybble, :nibble

        # A string (ie, multiple of 8 bits wide) containing all zeroes.
        # You could also just use
        #   num :width => whatever, :value => 0
        #
        def self.zero_pad(*args)
            with_args(*args) do |name, opts|
                str opts.merge(:name => name, :padding => "\x00")
            end
        end

        # A length field (specify the width, if it's not 32 bits
        # little-endian) --- its value will be :size of the following
        # field (or provide :offset)
        #
        def self.len(*args); with_args(*args) do |name, opts|
                opts[:width] ||= 32
                num name, opts.merge(:value => :size)
            end
        end

        # A bounded string, takes its size from the preceding element
        #
        def self.bounded(*args)
            with_args(*args) do |name, opts|
                opts[:size] ||= :value
                opts[:offset] ||= -1
                str name, opts
            end
        end

        # A string.
        def self.string(*args)
            with_args(*args) do |name, opts|
                str opts.merge(:name => name)
            end
        end

        # A Null byte
        def self.mark(*args)
            with_args(*args) do |name, opts|
                null opts.merge(:name => name)
            end
        end

        # 4-byte IP address (IPv4)
        def self.ipv4(*args)
            with_args(*args) do |name, opts|
                add(Ruckus::IP, opts.merge(:name => name))
            end
        end

        def self.choose(name, tag=nil, &block)
            add(Ruckus::Choice, :name => name, :block => block)
        end

        def self.base_pad(name, tag=nil)
            string name, :value => {:offset => :this, :block => lambda do |this|
                    r = this.root
                    r = r.find_tag_struct(tag) if tag
                    if ((k = this.rendered_offset - r.rendered_offset) % 4) != 0
                        pad = 4 - ((this.rendered_offset - r.rendered_offset) % 4)
                    else
                        pad = 0
                    end
                    "\x00" * pad
                end
            }
        end

        def self.word_len(*args); with_args(*args) do |name, opts|
                opts[:value] ||= :size
                opts[:width] ||= 16
                opts[:modifier] = lambda {|o, s| s/=2}
                num name, opts
            end
        end

        def self.msg_len(*args); with_args(*args) do |name, opts|
                opts[:value] = { :block => lambda do |n|
                        if not n.rendering
                            begin
                                n.rendering = true
                                n.parent_struct.size
                            ensure
                                n.rendering = false
                            end
                        else
                            4
                        end
                    end
                }
                opts[:width] ||= 32
                num name, opts
            end
        end
    end

    class Padding < Structure
        base_pad :pad
    end
end
