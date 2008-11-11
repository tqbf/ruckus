module Ruckus
    class Selector < String
        attr_reader :rid
        attr_reader :rclass
        attr_reader :rkind

        def initialize(s)
            if s =~ /(?:([^.#]+))?(?:\.([^.#]+))?(?:#(.+))?/
                @rkind, @rclass, @rid = [$1, $2, $3]
            else
                @rkind, @rclass, @rid = [nil, nil, s]
            end

            super
        end
    end

    class Parsel
        def index_for_selectors
            b = lambda {|h, k| h[k] = []}
            ids, classes, kinds = [Hash.new(&b), Hash.new(&b), Hash.new(&b)]

            visit do |n|
                k = n.class
                while k != Ruckus::Parsel and k != Object
                    kinds[k.to_s] << n                   
                    k = k.superclass
                end
                
                (ids[n.tag.to_s] << n) if n.tag
                (classes[n.name.to_s] << n) if n.name
            end
                        
            @selector_index = [ids, classes, kinds]
        end

        def each_matching_selector(sel)
            index_for_selectors if not @selector_index
            sels = sel.split.reverse.map {|x| Selector.new(x)}
            
            first = sels.shift
            
            ipool = first.rid    ? @selector_index[0][first.rid]    : nil
            cpool = first.rclass ? @selector_index[1][first.rclass] : nil
            kpool = first.rkind  ? @selector_index[2][first.rkind]  : nil
            
            pool = ipool || cpool || kpool
            pool = (pool & ipool) if ipool
            pool = (pool & cpool) if cpool
            pool = (pool & kpool) if kpool
                
            # XXX this loop is fucked:
            # outer loop needs to be pool
            # will capture parent nodes in arbitrary order
#             sels.each do |s|
#                 pool.each do |victim|
#                     found = false
#                     victim.root {|n| found = true if n.matches_selector? s}
#                     pool.delete(victim) if not found
#                 end
#             end

            pool.each do |victim|
                tmpsels = sels.clone
                cur = sels.shift

                victim.root do |parent|
                    break if not cur
                    if parent.matches_selector? cur
                        cur = sels.shift
                    end
                end
                
                pool.delete(victim) if cur
            end
            
            pool.each do |n|
                yield n
            end

            pool.size
        end
        
        def matches_selector?(sel)
            index_for_selectors if not @selector_index
            return false if sel.rid and sel.rid != self.tag
            return false if sel.rclass and sel.rclass != self.name
            return false if sel.rkind and not @selector_index[2][sel.rkind].include? self
            return true
        end
    end
end
