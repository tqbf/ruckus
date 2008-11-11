#!/usr/bin/env ruby
#
# = fuzz.rb
#
# Fuzz Generators
#
# Ruby 1.8 Generators use continuations (which are slow) and leak
# memory like crazy, so use generators.rb from Ruby 1.9.
#
# Author:: Dai Zovi, Dino <ddz@theta44.org>
# License:: Private
# Revision:: $Id$
#

require 'generator' 

module DFuzz
    # Generate Xi-F...Xi+F for each Xi in boundaries and fudge_factor F
    class Fudge < Generator
        def initialize(boundaries, fudge_factor, mask = nil)
            super() { |g|
                boundaries.each {|b|
                    0.upto(fudge_factor) { |f|
                        if (mask)
                            g.yield((b+f) & mask)
                            g.yield((b-f) & mask)
                        else
                            g.yield b+f
                            g.yield b-f
                        end
                    }
                }
            }
        end
    end

    # Serially generate each variable in turn (equivalent to
    # recursively nesting generators)
    class Block
        def initialize(defaults, generators)
            @defaults = defaults
            @generators = generators
        end
        
        def run(&block)
            generators_index = 0

            # Baseline
            block.call(@defaults)

            # Iterate through generators, fully exhausting each and
            # calling the code block with each set of values
            @generators.each { |g|
                values = Array.new(@defaults)
                while (g.next?)
                    values[generators_index] = g.next
                    block.call(values)
                end
                generators_index += 1;
            }
        end
    end

    class Integer < Fudge
        def initialize(delta = 128)
            super([0, 0x7FFF, 0xFFFF, 0x7FFFFFFF,
                   0x7FFFFFFFFFFFFFFF], delta)
        end
    end

    class Byte < Fudge
        def initialize(delta = 16)
            super([0x00, 0x01, 0x7F, 0xFF], delta, 0xFF)
        end
    end

    class Short < Fudge
        def initialize(delta = 128)
            super([0x0000, 0x0001, 0x7FFF, 0xFFFF], delta, 0xFFFF)
        end
    end
    
    class Long < Fudge
        def initialize(delta = 256)
            super([0x00000000, 0x0000001, 0x7FFFFFFF, 0xFFFFFFFF, 0x40000000, 0xC0000000], delta, 0xffffffff)
        end
    end

    class Char < Generator
        def initialize()
            c = ["A", "0", "~", "`", "!", "@", "#", "$", "%", "^", "&",
                 "*", "(", ")", "-", "=", "+", "[", "]", "\\", "|", ";", 
                 ":", "'", "\"", ",", "<", ".", ">", "/", "?", 
		 " ", "~", "_", "{", "}", "\x7f","\x00","\x01",
		 "\x02","\x03","\x04","\x05", "\x06","\x07","\x08","\x09",
		 "\x0a","\x0b","\x0c","\x0d", "\x0e","\x0f","\x10","\x11",
		 "\x12","\x13","\x14","\x15", "\x16","\x17","\x18","\x19",
		 "\x1a","\x1b","\x1c","\x1d", "\x1e","\x1f",
		 "\x80","\x81","\x82","\x83","\x84","\x85","\x86","\x87",
		 "\x88","\x89","\x8a","\x8b","\x8c","\x8d","\x8e","\x8f",
		 "\x90","\x91","\x92","\x93","\x94","\x95","\x96","\x97",
		 "\x98","\x99","\x9a","\x9b","\x9c","\x9d","\x9e","\x9f",
		 "\xa0","\xa1","\xa2","\xa3","\xa4","\xa5","\xa6","\xa7",
		 "\xa8","\xa9","\xaa","\xab","\xac","\xad","\xae","\xaf",
		 "\xb0","\xb1","\xb2","\xb3","\xb4","\xb5","\xb6","\xb7",
		 "\xb8","\xb9","\xba","\xbb","\xbc","\xbd","\xbe","\xbf",
		 "\xc0","\xc1","\xc2","\xc3","\xc4","\xc5","\xc6","\xc7",
		 "\xc8","\xc9","\xca","\xcb","\xcc","\xcd","\xce","\xcf",
		 "\xd0","\xd1","\xd2","\xd3","\xd4","\xd5","\xd6","\xd7",
		 "\xd8","\xd9","\xda","\xdb","\xdc","\xdd","\xde","\xdf",
		 "\xe0","\xe1","\xe2","\xe3","\xe4","\xe5","\xe6","\xe7",
		 "\xe8","\xe9","\xea","\xeb","\xec","\xed","\xee","\xef",
		 "\xf0","\xf1","\xf2","\xf3","\xf4","\xf5","\xf6","\xf7",
		 "\xf8","\xf9","\xfa","\xfb","\xfc","\xfd","\xfe","\xff", ]
            super(c)
        end
    end

    class String < Generator
        def initialize()
            super() { |g|
                # Fuzz strings are each of CHARS repeated each of
                # LENGTHS times and each of strings
                lengths = [16, 32, 64, 100, 128, 192, 256, 384, 512, 768, 1024, 2048, 3072, 4096, 6000, 8192, 10000, 16000, 20000, 32000, 50000, 64000, 72000,  100000]
                strings = [
                    "%n%n%n%n%n%n%n%n%n%n", "%252n%252n%252n%252n%252n",
                    "%x%x%x%x", "%252x%252x%252x%252x",
                    "../../../../../../../../../../../../../etc/passwd",
                    "../../../../../../../../../../../../../etc/passwd%00",
                    "../../../../../../../../../../../../../boot.ini",
                    "../../../../../../../../../../../../../boot.ini%00",
                    "..\\..\\..\\..\\..\\..\\..\\..\\..\\..\\boot.ini",
                    "..\\..\\..\\..\\..\\..\\..\\..\\..\\..\\boot.ini%00",
                    "<script>alert('XSS');</script>",
                    "A0`~!@#\$\%^&*()-_=+[]{}\\|;:',.<>/?\""
                ]
                chars = Char.new()
                while chars.next?
                    c = chars.next
                    
                    lengths.each { |l|
                        g.yield(c * l)
                    }
                end
                
                strings.each { |s|
                    g.yield(s)
                }
            }
        end
    end

    #
    # Modules for higher-level tokens (e-mail addresses, asn1, etc)
    #
    class EmailAddress < Generator
        def initialize()
        end
    end

end

####
# Unit test
####

if $0 == __FILE__
    puts "Testing integers..."
    i = 0
    integers = Fuzz::Integer.new()
    while integers.next?
        integers.next
        i += 1
    end
    puts "=> #{i} items"

    puts "Testing bytes..."
    i = 0
    bytes = Fuzz::Byte.new()
    while bytes.next?
        bytes.next
        i += 1
    end
    puts "=> #{i} items"

    puts "Testing shorts"
    i = 0
    shorts = Fuzz::Short.new()
    while shorts.next?
        shorts.next
        i += 1
    end
    puts "=> #{i} items"

    puts "Testing longs"
    i = 0
    longs = Fuzz::Long.new()
    while longs.next?
        longs.next
        i += 1
    end
    puts "=> #{i} items"

    puts "Testing characters"
    i = 0
    characters = Fuzz::Char.new()
    while characters.next?
        characters.next
        i += 1
    end
    puts "=> #{i} items"

    puts "Testing strings"
    i = 0
    strings = Fuzz::String.new()
    while strings.next?
        strings.next
        i += 1
    end
    puts "=> #{i} items"

    puts "Testing Block"
    b = Fuzz::Block.new(["FOO", "BAR"], 
                        [Fuzz::String.new(), Fuzz::String.new()])
    i = 0
    b.run() { |a, b|
        i += 1
    }
    puts "=> #{i} items"

end
