module Ruckus
    module StructureAllowFieldReplacement
        def template_entry_added_hook(obj)
            ## -------------------------------------------
            ## a quick dance to allow fields to replace other
            ## fields

            # check to see if it already exists, in which
            # case we want to replace the previous definition
            found = false
            @value.each_with_index do |x,i|
                if x.try(:name) == obj.try(:name)
                    found = i
                    break
                end
            end

            # it didn't exist, so add it to the structure
            if found
                # it did exist, so update the names index
                # and the previous entry in the structure

                self.class.structure_field_names[name] = found
                @value[found] = obj
            else
                false
            end
        end
    end
end
