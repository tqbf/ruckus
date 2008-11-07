class Integer
    # Convert integers to binary strings
    def to_l32; [self].pack "L"; end
    def to_b32; [self].pack "N"; end
    def to_l16; [self].pack "v"; end
    def to_b16; [self].pack "n"; end
    def to_u8; [self].pack "C"; end

    # Print a number in hex
    def to_hex(pre="0x"); pre + to_s(16); end

    # Print a number in binary
    def to_b(pre=""); pre + to_s(2); end
    
    def ffs
      i = 0
      v = self
      while((v >>= 1) != 0)
          i += 1
      end
      return i
    end
end
