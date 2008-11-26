module Ruckus
    module StructureInitializers
        def self.included(klass)
            klass.class_eval {
                class_inheritable_array :initializers
                write_inheritable_array :initializers, []
            }
        end

        def final_initialization_hook
            self.initializers.each {|cb| self.instance_eval(&cb) }
        end
    end
end
