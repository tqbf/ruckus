module Ruckus
    module StructureFixupFieldNames
        def structure_field_def_hook(*a)
            args = a[0]
            if args[0] and args[0].kind_of? Symbol
                if args[1]
                    args[1][:name] = args[0]
                else
                    args[1] = { :name => args[0] }
                end
                args.shift
            end
            super
        end
    end
end
