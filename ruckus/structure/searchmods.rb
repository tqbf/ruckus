module Ruckus
    module StructureSearchModules
        def self.included(klass)
            klass.class_eval {
                class_inheritable_array :search_modules
                write_inheritable_array :search_modules, []
            }

            klass.extend(ClassMethods)
        end

        module ClassMethods
            def derive_search_module
                if self.search_modules.empty?
                    return Ruckus
                else
                    mod = Module.new
                    self.search_modules.each do |m|
                        mod.module_eval "include #{ m.to_s.class_name }"
                    end
                    mod.module_eval "include Ruckus"
                    return mod
                end
            end

            def search_module(*args)
                args.each do |m|
                    self.search_modules << m
                end
            end
        end
    end
end
