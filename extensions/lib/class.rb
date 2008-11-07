class Class

    # Also crazy that this isn't in the library
    def inherits_from?(klass)
        return true if self == klass
        return true if self.superclass == klass
        return false if self.superclass == Object

        rec = lambda do |x|
            if x == Object
                false
            elsif x == klass
                true
            else
                rec.call(x.superclass)
            end
        end

        rec.call(self)
    end

    def alias_cmethod(to, from)
        (class << self;self;end).class_eval {
            define_method to do |*args|
                send(from, *args)
            end
        }
    end
end
