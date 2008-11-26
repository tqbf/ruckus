# === Most things you want to render are Numbers

module Ruckus
    # A Ruckus::Number is a type of Parsel that wraps an Integer.
    class Number < Parsel
        attr_accessor :width, :endian, :radix, :pad, :ascii
        attr_accessor :value


        # Options:
        # width::    (Default: 32) Width in bits --- can be odd!
        # endian::   (Default: :little) Endianness --- not honored for
        #            odd widths
        # value::    Usually a fixnum, but can be a method to call on
        #            sibling Parsel, e.g. :size for "Length" fields.
        #
        # Note: odd-width fields must be parented (see Blob or Structure)
        # to render or capture their values
        #
        def initialize(opts={})
            opts[:width] ||= 32
            opts[:endian] ||= :little
            # opts[:value] ||= 0xABADCAFE
            opts[:value] ||= 0
            opts[:radix] ||= 0

            if opts[:endian] == :native
                opts[:endian] = Parsel.endian?
            end
            super(opts)
        end

        private

        def widthcode
            case @width
            when 8;  code = "C"
            when 16; code = "S"
            when 32; code = "I"
            when 64; code = "Q"
            else
                nil
            end
        end

        public

        # this is some seriously weak shit down here

        # Is this an odd-width (single bit, nibble, etc) number?
        #
        def odd_width? ; not widthcode ; end

        private

        def span_start
            i_am = where_am_i?
            first = i_am
            (i_am - 1).downto(0) do |i|
                begin
                    break if not parent[i].odd_width?
                rescue
                    break
                end
                first = i
            end
            return first
        end

        public

        # For odd-width fields --- find how big the span of neighboring odd-width
        # fields is, in bits.
        #
        def span_bits
            last = where_am_i?
            span_start.upto(parent.count - 1) do |i|
                break if not parent[i].respond_to? :odd_width?
                break if not parent[i].odd_width?
                last = i
            end

            tot = 0
            span_start.upto(last) { |i| tot += parent[i].width }
            tot
        end

        # Where are we in the span of neighboring odd-width fields?
        #
        def span_offset
            tot = 0
            span_start.upto(where_am_i? - 1) {|i| tot += parent[i].width}
            tot
        end

        # Given: a string, return: the remainder of the string after
        # parsing the number, side-effect: populate @value
        #
        def capture(str)
            return ascii_capture(str) if @ascii
            return odd_width_capture(str) if not (code = widthcode)
            cap = str.shift(size)
            cap = cap.reverse if not Parsel.native?(@endian)
            @value = cap.unpack(code).first
            return str
        end

        BASERX = {
            2 => /([01]+)/,
            8 => /([0-7]+)/,
            10 => /([0-9]+)/,
            16 => /([0-9a-fA-F]+)/
        }

        def ascii_capture(str)
            # weak
            if (rad = resolve(@radix)) == 0
                if str.starts_with? "0x"
                    rad = 16
                    str.shift 2
                else
                    rad = 10
                end
            end

            if(str =~ BASERX[rad])
                @value = $1.to_i(rad)
                str.shift($1.size)
            else
                @value = 0
            end

            return str
        end

        # Quick hack: true is 1, false is 0, nil is 0.
        #
        def resolve(x)
            r = super
            r = 1 if r == true
            r = 0 if r == false
            r = 0 if r == nil
            return r
        end

        # Render this number (or, if odd-width, this span of odd-width
        # values, if we're the first element of the span) as a bit string.
        #
        def to_s(off=nil)
            @rendered_offset = off || 0

            begin
                if @ascii
                    r = ascii_to_s
                elsif not (code = widthcode)
                    r = odd_width_to_s
                else
                    val = resolve(@value).to_i
                    r = [val].pack(code)
                    r = r.reverse if @endian != Parsel.endian?
                end

                if off
                    return r, off+r.size
                else
                    return r
                end
            rescue
                raise
            end
        end

        def ascii_to_s
            if((rad = resolve(@radix)) == 0)
                rad = 10
            end

            pad = resolve(@pad) || 0
            @value.to_s(rad).rjust(pad, "0")
        end

        # Render a span of odd-width numbers as a byte string
        #
        def odd_width_to_s
            return "" if not odd_width_first?

            acc = 0
            tot = 0
            bits = span_bits

            # Cheat horribly: Ruby has bignums, so just treat the whole
            # span as one giant bignum and math it into place.

            where_am_i?.upto(parent.count - 1) do |i|
                break if not parent[i].respond_to? :odd_width?
                break if not parent[i].odd_width?
                acc <<= parent[i].width
                tot += parent[i].width
                acc |= parent[i].resolve(parent[i].value) & Numeric.mask_for(parent[i].width)
            end
            acc <<= 8 - (tot % 8) if (tot % 8) != 0

            # Dump the bignum to a binary string

            ret = ""
            while bits > 0
                ret << (acc & 0xff).chr
                acc >>= 8
                bits -= 8
            end

            ret.reverse! if @endian == :big
            return ret
        end

        # Are we the first odd-width number in the span?
        #
        def odd_width_first?
            return true if odd_width? and where_am_i? == 0
            begin
                not parent[where_am_i? - 1].odd_width?
            rescue
                true
            end
        end

        # Capture a whole span of odd-width numbers, see capture
        #
        def odd_width_capture(str)
            return str if not odd_width_first?

            cap = str.shift(Parsel.bytes_for_bits(span_bits))

            acc = 0
            cap.each_byte do |b|
                acc <<= 8
                acc |= b
            end
            tbits = cap.size * 8
            tot = 0
            where_am_i?.upto(parent.count - 1) do |i|
                break if not parent[i].respond_to? :odd_width?
                break if not parent[i].odd_width?
                tot += parent[i].width
                parent[i].value = (acc >> (tbits - tot)) & Numeric.mask_for(parent[i].width)
            end

            return str
        end

        # How big is the encoded number?
        #
        def size
            if not odd_width?
                s = Parsel.bytes_for_bits(@width);
            elsif odd_width_first?
                s = span_bits * 8
            else
                s = 0
            end
            s
        end
    end

    Num = Number.clone
    
    ## ---------------------------------------------------------
    ## XXX DRY, refactoring in process
    ##
    ## Moved this from classmethods to classes so we can encode
    ## more into the type, useful for selectors

    class Le16 < Number
        def initialize(opts={}); super(opts.merge(:width => 16, :endian => :little))
        end
    end

    # For no good reason, "halfwords" are little endian, but "shorts" are
    # network byte order. You're welcome.

    H16, Uint16le, Half, Halfword = [ Le16.clone, Le16.clone, Le16.clone, Le16.clone ]

    class Le32 < Number
        def initialize(opts={}); super(opts.merge(:width => 32, :endian => :little))
        end
    end

    H32 = Le32.clone
    Uint32le = Le32.clone

    class Le64 < Number
        def initialize(opts={}); super(opts.merge(:width => 64, :endian => :little))
        end
    end

    H64 = Le64.clone
    Uint64le = Le64.clone

    class Be16 < Number
        def initialize(opts={}); super(opts.merge(:width => 16, :endian => :big))
        end
    end

    N16, Uint16be, Short = [Be16.clone, Be16.clone, Be16.clone]

    class Be32 < Number
        def initialize(opts={}); super(opts.merge(:width => 32, :endian => :big))
        end
    end

    N32 = Be32.clone
    Uint32be = Be32.clone

    class Be64 < Number
        def initialize(opts={}); super(opts.merge(:width => 64, :endian => :big))
        end
    end

    N64 = Be64.clone
    Uint64be = Be64.clone

    class Byte < Number
        def initialize(opts={}); super(opts.merge(:width => 8))
        end
    end

    Le8, Be8, N8, H8 = [Byte.clone, Byte.clone, Byte.clone, Byte.clone]

    class Bit < Number
        def initialize(opts={}); super(opts.merge(:width => 1))
        end
    end

    class Nibble < Number
        def initialize(opts={}); super(opts.merge(:width => 4))
        end
    end
    Nybble = Nibble.clone

    # A length field (specify the width, if it's not 32 bits
    # little-endian) --- its value will be :size of the following
    # field (or provide :offset)

    class Len < Number
        def initialize(opts={})
            super(opts.merge(:width => 32, :value => :size))
        end
    end

    class Decimal < Ruckus::Number
        OPTIONS = { :ascii => true, :radix => 10 }
    end

end
