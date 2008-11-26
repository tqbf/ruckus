module Ruckus
    module StructureProxies
        class ValueProxy
            def initialize(target); @t = target; end
            def method_missing(meth, *args)
                if meth.to_s.ends_with? "="
                    @t.send(meth, *args)
                else
                    @t.send(meth).send(:value)
                end
            end
        end

        class NodeProxy
            def initialize(target); @t = target; end
            def method_missing(meth, *args)
                if meth.to_s.ends_with? "="
                    @t.send(meth, *args)
                else
                    @t[meth]
                end
            end
        end

        def v; ValueProxy.new(self); end
        def n; NodeProxy.new(self); end
    end
end
