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

        def self.char(*args); with_args(*args) {|name, opts| str opts.merge(:name => name, :size => 1)}; end

        def self.decimal(*args); with_args(*args) {|name, opts| num name, opts.merge(:ascii => true, :radix => 10)}; end
        def self.hex_number(*args); with_args(*args) {|name, opts| num name, opts.merge(:ascii => true, :radix => 16)}; end

        def self.tag_bit(*args); with_args(*args) {|name, opts| num name, opts.merge(:width => 1, :tag => name)}; end

        # A string (ie, multiple of 8 bits wide) containing all zeroes.
        # You could also just use
        #   num :width => whatever, :value => 0
        #
        def self.zero_pad(*args)
            with_args(*args) do |name, opts|
                str opts.merge(:name => name, :padding => "\x00")
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
