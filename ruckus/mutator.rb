# === Mutator is a half-assed fuzzing framework intended to snap in to Ruckus.
# Mutator provides a decorator-style interface to fuzzed integers and strings,
# so that you can chain them to get strings that grow and include metacharacters
# with X probability, etc.
#
# There are two core objects in here:
# * <tt>Mutator</tt> is a base type, like a String or an Integer, wrapped
#   in an object that provides a <tt>permute</tt> method to change the
#   value, and a stack of <tt>Modifier</tt> objects.
# * <tt>Modifier</tt> is an object that takes a value and changes it
#   to do evil. Modifiers chain.
#
# This stuff is really kind of an afterthought; the real work in building
# fuzzer is getting the encoding right, so you can reach more of the target
# code. Ruckus hides the details of how strings and integers are actually
# encoded, so most of the "fuzzing" part just comes down to making evil
# looking strings. The Parsel framework takes care of encoding those evil
# strings properly so that a CIFS stack will read them.
#
module Ruckus
    module Mutator

        # Create me with a String, and I wrap the string, forwarding method
        # invocations to it. Call "permute" and I'll run through my Modifier
        # chain to derive a new value (for instance, tripling the number of
        # characters).
        #
        class Mutator

            # <tt>base</tt> is usually a String (like "helu") or Fixnum.
            # Stack is a set of modifier objects (or class names, if you
            # just want to use the defaults). A Mutator with an empty
            # Modifier stack doesn't do anything and behaves just like an
            # ordinary String or Fixnum.
            #
            def initialize(base=nil, stack=[])
                @base = base
                @cur = @base
                @stack = stack.map do |o|
                    o = o.new if o.kind_of? Class
                    o
                end
            end

            def method_missing(meth, *args)
                @cur.send(meth, *args)
            end

            # A fuzzer clock tick; mess up the enclosed value.
            #
            def permute
                @cur = @stack.inject(@cur) {|cur, mod| mod << cur}
            end
        end

        # The guts; each Modifier class implements some way of screwing
        # with a value to catch bugs. Modifiers are all created with
        # keyword args; the base class catches:
        # now::        true/false (def: false) fire immediately, just once,
        #              irrespective of probability, even if probability is
        #              provided.
        # prob::       (def: 100) pctg chance this modifier will fire on this
        #              tick
        # max_steps::  number of times to fire this modifier before it stops
        #              and just starts acting like a no-op. -1 equals no max
        #
        class Modifier
            def initialize(opts={})
                @now = opts[:now] || false
                @prob = opts[:prob] || 100
                @max_steps   = opts[:max_steps] || 700
                @cur   = 0
                @opts = opts
            end

            # Should this fire, based on prob?
            #
            def go?
                if @now
                    @now = false
                    return true
                end
                rand(100) < @prob
            end

            # Base class stub does nothing. Subclasses override this method
            # to implement logic. Callers don't use this method, though: they
            # use operator<<.
            #
            def mod(x); x; end

            # This is what callers call. Subclasses do not override this
            # method. This implements probability and max-steps. How it
            # looks:
            #
            #   str = modifier << str
            #
            def <<(x)
                return x if (@cur += 1) > @max_steps && @max_steps != -1
                return x if not go?
                mod(x)
            end
        end

        # Geometrically increases size.
        #
        # A
        # AA
        # AAAA
        # AAAAAAAA ... etc
        #
        class Multiplier < Modifier

            # Takes:
            # multiplier::    (def: 2) how much to multiply by.
            #
            def initialize(opts={})
                @step  = opts[:multiplier] || 2
                super
            end

            def mod(x)
                x * @step
            end
        end

        # Adds fixed amounts of data.
        #
        # A
        # AA
        # AAA
        # AAAA ... etc
        #
        class Adder < Modifier

            # Takes:
            # base::       (def: "A") what to add
            # step::       (def: 100) how much of this to add at each step
            #
            def initialize(opts={})
                @base  = opts[:base] || "A"
                @step  = opts[:step]  || 100
                super
            end

            def mod(x)
                if x.kind_of? String
                    x + (@base * @step)
                else
                    x + @step
                end
            end
        end

        # Path traversal metacharacters and keywords, cycled. Add new
        # ones to the STRINGS array.
        #
        class PathTraversal < Modifier
            STRINGS = [ "etc/passwd",
                        "etc/passwd\x00",
                        "etc/passwd%00",
                        "boot.ini",
                        "boot.ini\x00",
                        "boot.ini%00" ]
            def mod(x)
                x = x + ("../" * (@cur + 1)) + STRINGS[@cur % STRINGS.size]
                if (@cur % 2) == 0
                    x.gsub!("/", "\\")
                end
                return x
            end
        end

        # The format strings, cycled. Add new ones to the STRINGS array.
        #
        class FormatStrings < Modifier
            STRINGS = [ "%n", "%25n", "%s", "%x" ]

            def mod(x)
                x + STRINGS[@cur % STRINGS.size]
            end
        end

        # The most likely evil metachars, but if you're thorough, you
        # just try all non-isalnums.
        #
        class Metacharacters < Modifier
            STRINGS = [ ".", "/", "\\", "$", "-", "%", "$", ";",
                        "'", '"', "*", "\x00" ]

            def mod
                x = x + STRINGS[@cur % STRINGS.size]
                if opts[:hexify]
                    0.upto(x.size - 1) do |i|
                        x[i] = "%#{ x[i].to_s(16) }"
                    end
                end
                return x
            end
        end

        # Things that will break SQL queries.
        #
        class SQLStrings < Modifier
            STRINGS = [ "'sql0", "+sql1", "sql2;", "sql3 ;--", "(sql4)" ]

            def mod
                x + STRINGS[@cur % STRINGS.size]
            end
        end

        # Trivial XSS tickler.
        #
        class XSS < Modifier
            def mod
                x + "<script>alert(document.location);</script>"
            end
        end

        # Generate random numbers
        #
        class Random < Modifier
            def initialize(opts={})
                srand((@seed = opts[:seed])) if opts[:seed]
                super
                @max = opts[:max] || 0xFFFFFFFF
                if opts[:width]
                    @max = Numeric.mask_for(opts[:width])
                end
            end

            def mod(i)
                rand(@max)
            end
        end

        # Randomly sets the top bit of each byte, turning ASCII into
        # hi-ASCII.
        #
        class Hibit < Modifier
            def initialize(opts={})
                opts[:prob] ||= 50
                @width = opts[:width] || 32
                super
            end

            def mod(x)
                if x.kind_of? String
                    0.upto(x.size - 1) do |i|
                        x[i] |= 0x80 if go?
                    end
                else
                    x |= (0x80 << (@width - 8))
                end
                return x
            end
        end

        # Cache the starting value (this is meant to the be first modifier
        # in the chain, if you're using it) and randomly reset the string
        # back to that starting value.
        #
        class Reset < Modifier
            def initialize(opts={})
                opts[:prob] ||= 25
                super(opts.merge(:now => true))
            end

            def mod(x)
                (@orig ||= x.clone).clone
            end
        end

        # Randomize a string.
        #
        class Randomizer < Modifier
            def mod(x)
                0.upto(x.size-1) do |i|
                    x[i] = rand(0xff)
                end
                return x
            end
        end

        # Wrap Number with Mutator, make to_i work.
        #
        class Number < Mutator
            def initialize(base=0, stack=[]); super; end
            def to_i; @cur.to_i; end
        end

        # Wrap String with Mutator, make to_s work.
        #
        class Str < Mutator
            def initialize(base="", stack=[]); super; end
            def to_s(off=nil); @cur.to_s; end
        end

        class << self
            def random_int(opts={})
                Number.new(1, [Random.new(opts)])
            end

            def r8; random_int(:width => 8); end
            def r16; random_int(:width => 16); end
            def r32; random_int(:width => 32); end
            def r64; random_int(:width => 64); end

            def grostring(base="A", opts={})
                Str.new(base, [Reset, Adder.new(opts)])
            end

            def randstr(base="A")
                Str.new(base, [Reset, Randomizer])
            end
        end
    end
end
