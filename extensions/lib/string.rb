%w[iconv stringio].each {|x| require x}

class String
    # Convert a string to "Unicode", ie, the way Win32 expects it, including
    # trailing NUL.
    def to_utf16
        Iconv.iconv("utf-16LE", "utf-8", self).first + "\x00\x00"
    end

    # Convert a "Unicode" (Win32-style) string back to native Ruby UTF-8;
    # get rid of any trailing NUL.
    def from_utf16
        ret = Iconv.iconv("utf-8", "utf-16le", self).first
        if ret[-1] == 0
            ret = ret[0..-2]
        end
    end
    alias_method :to_utf8, :from_utf16
    alias_method :to_ascii, :from_utf16
    
    # Convenience for parsing UNICODE strings from a buffer
    # Assumes last char ends in 00, which is not always true but works in English
    def from_utf16_buffer
        self[0..index("\0\0\0")+2].from_utf16
    end

    # Sometimes string buffers passed through Win32 interfaces come with
    # garbage after the trailing NUL; this method gets rid of that, like
    # String#trim
    def asciiz
        begin
            self[0..self.index("\x00")-1]
        rescue
            self
        end
    end

    # My entry into the hexdump race. Outputs canonical hexdump, uses
    # StringIO for speed, could be cleaned up with "ljust", and should
    # probably use table lookup instead of to_s(16) method calls.
    def hexdump(capture=false)
        sio = StringIO.new
        rem = size - 1
        off = 0

        while rem > 0
            pbuf = ""
            pad = (15 - rem) if rem < 16
            pad ||= 0

            sio.write(("0" * (8 - (x = off.to_s(16)).size)) + x + "  ")

            0.upto(15-pad) do |i|
                c = self[off]
                x = c.to_s(16)
                sio.write(("0" * (2 - x.size)) + x + " ")
                if c.printable?
                    pbuf << c
                else
                    pbuf << "."
                end
                off += 1
                rem -= 1
                sio.write(" ") if i == 7
            end

            sio.write("-- " * pad) if pad > 0
            sio.write(" |#{ pbuf }|\n")
        end

        sio.rewind()
        if capture
            sio.read()
        else
            puts sio.read()
        end
    end

    # convert a string to its idiomatic ruby class name
    def class_name
        r = ""
        up = true
        each_byte do |c|
            if c == 95
                if up
                    r << "::"
                else
                    up = true
                end
            else
                m = up ? :upcase : :to_s
                r << (c.chr.send(m))
                up = false
            end
        end
        r
    end

    # Insane that this isn't in the library by default.
    def starts_with? x
        self[0..x.size-1] == x
    end

    def ends_with? x
        self[-(x.size)..-1] == x
    end

    # Cribbed from Ero Carrera's pefile; a relatively expensive entropy
    # function, gives a float result of random-bits-per-byte.
    def entropy
        e = 0
        0.upto(255) do |i|
            x = count(i.chr)/size.to_f
            if x > 0
                e += - x * Math.log2(x)
            end
        end

        return e
    end

    # The driver function for String#strings below; really, this will
    # run on any Enumerable that contains Fixnums.
    def nextstring(opts={})
        off = opts[:offset] || 0
        sz = opts[:minimum] || 7
        u = opts[:unicode] || false
        l = size
        i = off
        while i < l
            if self[i].printable?
                start = i
                cnt = 1
                i += 1
                lastu = false
                while i < l
                    if self[i].printable?
                        lastu = false
                        cnt += 1
                        i += 1
                    elsif u and self[i] == 0 and not lastu
                        lastu = true
                        i += 1
                    else
                        break
                    end
                end

                return([start, i - start]) if cnt >= sz
            else
                i += 1
            end
        end

        return false, false
    end

    # A la Unix strings(1). With a block, yields offset, string length,
    # and contents. Otherwise returns a list. Accepts options:
    # :unicode:  superficial but effective Win32 Unicode support, skips NULs
    # :minimum:  minimum length of returned strings, ala strings -10
    def strings(opts={})
        ret = []
        opts[:offset] ||= 0
        while 1
            off, size = nextstring(opts)
            break if not off
            opts[:offset] += (off + size)
            if block_given?
                yield off, size, self[off,size]
            else
                ret << [off, size, self[off,size]]
            end
        end
        ret
    end

    # A hacked up adler16 checksum, a la Andrew Tridgell. This is probably
    # even slower than Ruby's native CRC support. A weak, trivial checksum,
    # part of rsync.
    def adler
        a, b = 0, 0
        0.upto(size-1) {|i| a += self[i]}
        a %= 65536
        0.upto(size-1) {|i| b += ((size-i)+1) * self[i]}
        b %= 65536
        return (a|(b<<16))
    end

    # Convert binary strings back to integers
    def to_l32; unpack("L").first; end
    def to_b32; unpack("N").first; end
    def to_l16; unpack("v").first; end
    def to_b16; unpack("n").first; end
    def to_u8; self[0]; end
    def shift_l32; shift(4).to_l32; end
    def shift_b32; shift(4).to_b32; end
    def shift_l16; shift(2).to_l16; end
    def shift_b16; shift(2).to_b16; end
    def shift_u8; shift(1).to_u8; end

    # oh, it's exactly what it sounds like.
    def method_name
        r = ""
        scoped = false
        each_byte do |c|
            if c == 58
                if not scoped
                    r << "_"
                    scoped = true
                else
                    scoped = false
                end
            else
                if r.size == 0
                    r << c.chr.downcase
                else
                    if c.upper?
                        r << "_"
                        r << c.chr.downcase
                    else
                        r << c.chr
                    end
                end
            end
        end
        return r
    end

    # I love you String#ljust
    def pad(size, char="\x00")
        ljust(size, char)
    end

	# Convert a string into hex characters
	def hexify
		l = []
		each_byte{|b| l << "%02x" % b}
		l.join
	end

    # convert a string to hex characters in place
  def hexify!
    self.replace hexify
  end


    # Convert a string of raw hex characters (no %'s or anything) into binary
    def dehexify
        (ret||="") << (me||=clone).shift(2).to_i(16).chr while not (me||=clone).empty?
        return ret
    end

    # Convert a string of raw hex characters (no %'s or anything) into binary in place
    def dehexify!
        (ret||="") << (me||=clone).shift(2).to_i(16).chr while not (me||=clone).empty?
        self.replace ret
    end

    # OR two strings together. Slow. Handles mismatched lengths by zero-extending
    def or(str)
        max = size < str.size ? str.size : size
        ret = ""
        0.upto(max-1) do |i|
            x = self[i] || 0
            y = str[i] || 0
            ret << (x | y).chr
        end
        return ret
    end
    
    # XOR two strings. wrapping around if str is shorter thn self.
    def xor(str)
      r = []
      size.times do |i|
        r << (self[i] ^ str[i % str.size]).chr
      end
      return r.join
    end
    
    def xor!(str)
      size.times do |i|
        self[i] ^= str[i % str.size]
      end
    end
    
    # byte rotation cypher (yes it's been useful)
    def rotate_bytes(k=0)
      r = []
      each_byte do |b|
        r << ((b + k) % 256).chr
      end
      return r.join
    end
    
    # Insanely useful shorthand: pop bytes off the front of a string
    def shift(count=1)
        return self if count == 0
        slice! 0..(count-1)
    end

    def underscore
	first = false
        gsub(/[a-z0-9][A-Z]/) do |m|
            "#{ m[0].chr }_#{ m[1].chr.downcase }"
        end
    end

    # "foo: bar".shift_tok /:\s*/ => "foo" # leaving "bar"
    def shift_tok(rx)
        src = rx.source if rx.kind_of? Regexp
        rx = Regexp.new "(#{ src })"
        idx = (self =~ rx)
        if idx
            ret = shift(idx)
            shift($1.size)
            return ret
        else
            shift(self.size)
        end
    end
end
