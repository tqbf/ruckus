module Ruckus
    module StructureAtCreate
        def self.included(klass)
            klass.extend(ClassMethods)
        end

        module ClassMethods
            def at_create(arg=nil, &block)
                if not block_given?
                    raise "need a callback function" if not arg
                    arg = arg.intern if not arg.kind_of? Symbol
                    block = lambda { send(arg) }
                end

                self.class.initializers << block
            end

            def override(field, val)
                at_create { self[field] = val }
            end
        end
    end
end
