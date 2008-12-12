module Ruckus
    module StructureDefaultValues
        def self.included(klass)
            klass.extend(ClassMethods)
        end

        def final_initialization_hook
            instance_variables.grep(/^@with_.*/).each do |v|
                v =~ /@with_(.*)/
                var = $1
                send((var + "=").intern, instance_variable_get(v.intern))
            end
            super
        end

        # XXX probably not needed
#         def template_entry_added_hook(obj)
#             obj.instance_variables.grep(/^@with_.*/).each do |v|
#                 v =~ /@with_(.*)/
#                 var = $1
#                 obj.send((var + "=").intern, obj.instance_variable_get(v.intern))
#             end
#             super
#         end

        def method_missing_hook(meth, args)
            m = meth.to_s
            setter = (m[-1].chr == "=") ? true : false
            m = m[0..-2] if setter
            if setter and (field = self[m.intern])
                if(field.kind_of? Structure)
                    if args[0].kind_of? field.class
                        args[0].each_field do |name, f|
                            field.value = f.value
                        end
                    else
                        if((deft = field.instance_variable_get :@default_field))
                            field.send(deft.to_s + "=", args[0])
                            return false
                        else
                            puts "WARNING: attempt to set structure field with no default_field declared"
                        end
                    end
                end
            end
            true
        end

        module ClassMethods
            def default_field(f)
                self.initializers << lambda do
                    @default_field = f
                end
            end
        end
    end
end
