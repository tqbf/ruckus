module Ruckus
    module StructureBeforeCallbacks
        def self.included(klass)
            klass.extend(ClassMethods)

            klass.class_eval {
                class_inheritable_array :before_callbacks
                write_inheritable_array :before_callbacks, []
            }
        end

        def before_render_hook
            self.class.before_callbacks.each {|cb| self.instance_eval(&cb)}
        end

        module ClassMethods
            def before_render(arg=nil, &block)
                if not block_given?
                    raise "need a callback function" if not arg
                    arg = arg.intern if not arg.kind_of? Symbol
                    block = lambda { send(arg) }
                end

                self.before_callbacks << block
            end
        end
    end
end
