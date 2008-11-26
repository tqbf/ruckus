class Range
    module RangeExtensions
        # again, surprised this isn't in the library
        def each_backwards
            max.to_i.downto(min) {|i| yield i}
        end

        # Take a random number out of a range
        #
        def choice
            rand(self.last - self.first) + self.first
        end
        alias_method :choose, :choice
    end
    include RangeExtensions
end
