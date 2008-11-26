module Ruckus
    module StructureValidateField
        def structure_field_def_hook(*a)
            args = a[0]

            if [ "value", "name", "size" ].include?(nm = args[0][:name] && args[0][:name].to_s) or (nm and nm.starts_with? "relate_")
                raise "can't have fields named #{ nm }, because we suck; rename the field"
            end
        end
    end
end
