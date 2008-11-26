class Array
    module ArrayExtensions
        # Assume an array of key, value tuples, and convert to Hash
        def to_hash
            r = {}
            each {|it| r[it[0]] = it[1]}
            return r
        end

        def kind_of_these? y
            inject(false) {|acc, klass| acc || y.kind_of?(klass)}
        end

        #return first hash-like element with key k
        def kassoc(k)
            each { |h| return h if h.try(:has_key?, k) }
            return nil
        end

        #return first hash-like element with value v
        def vassoc(v)
            each { |h| return h if h.try(:has_value?, v) }
            return nil
        end

        def extract_options!
            last.is_a?(::Hash) ? pop : {}
        end
    end
    include ArrayExtensions
end
