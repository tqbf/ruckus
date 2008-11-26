class Fixnum
    module FixnumExtensions
        # Ridiculous that this isn't in the library.
        def printable?; self >= 0x20 and self <= 0x7e; end

        # Like Numeric#Step, but yields the length of each span along with
        # the offset. Useful for stepping through data in increments:
        # 0.stepwith(buffer.size, 4096) {|off,len| pp buffer[off,len]}
        # The "len" parameter accounts for the inevitable short final block.
        def stepwith(limit, stepv, &block)
            step(limit, stepv) do |i|
                remt = limit - i
                yield i, remt.cap(stepv)
            end
        end

        # you can't clone a fixnum? Why?
        def clone; self; end

        def upper?; self >= 0x41 and self <= 0x5a; end
        def lower?; self >= 0x61 and self <= 0x7a; end
    end
    include FixnumExtensions
end

