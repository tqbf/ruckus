module Ruckus
    module StructureDetectFactory
        def factory?
            self.respond_to? :factory
        end

        def structure_field_def_hook(*a)
            args = a[0]
            opts = args[0].respond_to?(:has_key?) ? args[0] : args[1]
            include StructureFactory if opts.try(:has_key?, :decides)
            super
        end        
    end
    
    module StructureFactory
        def self.included(klass)
            klass.extend(ClassMethods)
        end

        module ClassMethods
            def factory(str)
                orig = str.clone
                (tmp = self.new).capture(str)
                tmp.each_field do |n, f|
                    if (m = f.try(:decides))
                        klass = m[f.value]
                        if klass
                            o = derive_search_module.const_get(klass.to_s.class_name).new
                            orig = o.capture(orig)
                            return o, orig
                        end
                    end
                end
                return false
            end
        end
    end
end
