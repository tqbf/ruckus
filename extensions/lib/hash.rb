class Hash
    module HashExtensions
        # XXX does the same thing as Hash#invert i think?
        def flip
            map {|k,v| [v,k]}.to_hash
        end
    end
    include HashExtensions
end
