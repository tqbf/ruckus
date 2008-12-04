# === Pretty much anything that isn't a Number is a Str

# class Symbol
#     def clone
#         self # fuck you ruby, what the fuck is wrong with you
#     end
# end

module Ruckus
    # A Ruckus::Str is a bag of bytes, wrapping a Ruby string
    class Str < Parsel
        # Options include:
        # size::     :min = :max = :size
        # min::      string will be padded to this size
        # max::      string will be cut off at this size
        # padding::  (Default: "\x00") --- what to pad with
        # value::    Normally a string
        # unicode::  Convert to UTF-16-LE before rendering
        #
        def initialize(opts={})
            opts[:bounded_by] ||= -1 if opts[:bounded]

            if opts[:bounded_by]
                opts[:size] = { :offset => opts[:bounded_by], :meth => :value }
            end

            if opts[:size]
                opts[:min] = opts[:size]
                opts[:max] = opts[:size]
                @in_size = opts[:size]
            end
            opts[:padding] ||= "\x00"
            opts[:min] ||= 0

            super(opts)

            @value = @value.clone if @value
            @value ||= ""
        end

        # As with Parsel; take a string, return what's left, capture the
        # value in @value.
        #
        def capture(str)
            if @in_size
                max = resolve(@in_size)
                min = resolve(@in_size)
            end

            max ||= resolve(@max)
            min ||= resolve(@min)
            pad = resolve(@padding)
            nul = resolve(@nul_terminated)
            uni = resolve(@unicode)
            del = resolve(@delimiter)

            @value = nil

            incomplete! if not str

            if (s = size)
                incomplete! if str.size < s
                cap = str[0...s]
            elsif nul
                nterm = str.index(uni ? "\000\000" : "\000")
                if nterm
                    cap = str[0...nterm]
                else
                    cap = str
                end
            elsif del
                if((idx = str.index(del)))
                    cap = str[0...idx]
                else
                    cap = str
                end
            else
                cap = str
            end

            cap = cap[0...max] if max
            while cap.size < min
                cap << pad
            end

            @value = uni ? cap.to_ascii : cap

            fin = -1
            mod = nul ? 1 : 0

            str.slice! 0, (cap.size + mod)
            return str
        end

        # As per Parsel, write the string
        def to_s(off=nil)
            @rendered_offset = off || 0

            min = resolve(@min)
            max = resolve(@max)
            uni = resolve(@unicode)
            val = (resolve(@value) || "").to_s
            val = val.clone # gross!
            pad = resolve(@padding)
            nul = resolve(@nul_terminated)
            pto = resolve(@pad_to)

            val << "\x00" if nul and val[-1] != 0

            val = val.to_utf16 if uni

            while min and val.size < min
                val << pad
            end

            if pto
                while ((val.size % pto) != 0) # this is some shameful shit right here
                    val << pad
                end
            end

            val = val[0...max] if max

            if off
                return val, off + val.size
            else
                return val
            end
        end
    end

## ---------------------------------------------------------

    class Asciiz < Str
        def initialize(opts={})
            opts[:nul_terminated] ||= true
            super(opts)
        end
    end

## ---------------------------------------------------------

    class Unicode < Str
        def initialize(opts={})
            opts[:unicode] ||= true
            super(opts)
        end
    end

## ---------------------------------------------------------

    class Unicodez < Unicode
        def initialize(opts={})
            opts[:nul_terminated] ||= true
            super(opts)
        end
    end
    Uniz = Unicodez # XXX compat

## ---------------------------------------------------------

end

