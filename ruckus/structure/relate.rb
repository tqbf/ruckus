module Ruckus
    module StructureRelateDeclaration
        def class_method_missing_hook(meth, *args)
            if meth.to_s =~ /^relate_(.*)/
                relate($1.intern, *args)
                return false
            end
            true
        end

        def relate(attr, field, opts={})
            opts[:through] ||= :value
            raise "need a valid field to relate" if not field
            raise "need :to argument" if not opts[:to]

            self.initializers << lambda do
                f = send(field)

                case attr
                when :value
                    f.value = opts[:through]
                    f.instance_eval { @from_field = opts[:to] }
                when :size
                    f.instance_eval {
                        @in_size = {
                            :meth => opts[:through],
                            :from_field => opts[:to]
                        }
                    }
                end
            end
        end
    end
end
