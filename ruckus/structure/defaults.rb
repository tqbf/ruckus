module Ruckus
    module StructureDefaultValues
        def template_entry_added_hook(obj)
            obj.instance_variables.grep(/^@with_.*/).each do |v|
                v =~ /@with_(.*)/
                var = $1
                obj.send((var + "=").intern, obj.instance_variable_get(v.intern))
            end
            super
        end
    end
end
