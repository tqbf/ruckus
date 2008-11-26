# === Structures are blobs with symbol tables.
#

Dir[File.expand_path("#{File.dirname(__FILE__)}/structure/*.rb")].each do |file|
    require file
end

module Ruckus
    # A Ruckus::Structure wraps a Ruckus::Blob, giving each of the fields
    # a name. Additionally, Structure has classmethod shorthand for DSL-style
    # descriptions of frame/packet formats; see below.
    #
    # Extend Structure by subclassing. Inside the subclass definition,
    # declare fields, like:
    #
    #    class Foo < Structure
    #        number :width => 32, :endian => :little
    #        str    :size => 10
    #    end
    #
    # Structure catches classmethod calls and converts them to
    # requests to add Parsels to the structure definition.
    #
    # You can inherit indefinitely (each subclass inherits the parent
    # class fields), and you can (obvious) nest --- fields are just
    # parsels.
    #
    class Structure < Parsel
        include StructureAllowFieldReplacement
        include StructureInitializers
        include StructureAtCreate
        include StructureBeforeCallbacks
        include StructureProxies

        class_inheritable_array :templates
        class_inheritable_hash  :structure_field_names

        (class << self;self;end).class_eval {
            include StructureRelateDeclaration

            def class_method_missing_hook(meth, *args); super; end

            # Rules for converting classmethod calls to types:
            # 1.   Convert to uppercase
            # 2.   If last arg is an opts hash, pull :from, use as module
            # 3.   Otherwise, use Ruckus as the module
            # 4.   Look up the uppercased name in the module
            # 5.   Call #new on it (when the object is instantiated)
            #
            def method_missing(meth, *args)
                return if not class_method_missing_hook(meth, *args)

                if not args[-1].kind_of? Hash or not (mod = args[-1][:from])
                    mod = Ruckus
                end

                if args[0] and args[0].kind_of? Symbol
                    if args[1]
                        args[1][:name] = args[0]
                    else
                        args[1] = { :name => args[0] }
                    end
                    args.shift
                end

                if [ "value", "name", "size" ].include?(nm = args[0][:name] && args[0][:name].to_s) or (nm and nm.starts_with? "relate_")
                    raise "can't have fields named #{ nm }, because we suck; rename the field"
                end

                begin
                    klass = mod.const_get(meth.to_s.class_name)
                rescue
                    pp "bad #{ meth }"
                    raise
                end

                add(klass, *args)
            end
        }

        # If you have an actual class reference, you can just pass
        # it to <tt>add</tt>, as in:
        #
        #   add(HeaderStructure, :name => :header)
        #
        def self.add(*args)
            raise "no class" if not args[0]

            write_inheritable_array :templates, [[args[0], args[1..-1]]]
        end

        private
        def template_decoder_ring(t)
            # Gross. Fields normally take a first argument, a symbol,
            # specifying the name, and then an opts hash. They can
            # also just take an options hash, in which case we expect
            # the name to be in the hash as :name. Extra fun: you
            # don't have to name every field, and things will still work.
            #
            if t[1][0].kind_of? Symbol and (not t[1][1] || t[1][1].kind_of?(Hash))
                t[1][1] ||= {}
                t[1][1][:name] = (name = t[1][0])
                t[1] = [t[1][1]]
            elsif t[1][0].kind_of? Hash
                name = t[1][0][:name]
            end
            return name
        end

        def template_entry_added_hook(*args); super *args; end
        def final_initialization_hook(*args); super *args; end

        public
        # No special options yet. A structure is just a parsel; pass
        # options through to the parent class.
        #
        def initialize(opts={})

            # A Structure is really just a Blob with extra goop
            @value = Blob.new
            @value.parent = self

            # Most of the goop is for figuring out what fields to
            # add, with what arguments, given where we are in the
            # inheritance hierarchy.

            template = self.class.templates

            # If this is the first time we're seeing this definition,
            # we also need to convert field names into blob offsets.
            pop = false
            if not self.class.structure_field_names
                self.class.write_inheritable_hash :structure_field_names, {}
                pop = true
            end

            template.each do |t|
                # do some rewriting to support an old style of declaring
                # fields that we supported like 6 months ago.
                name = template_decoder_ring(t)

                # index the field name if this is the first time we've
                # ever instantiated this kind of structure, and the field
                # is valid
                self.class.structure_field_names[name] = @value.count if (name and pop)

                begin
                    # create the structure field object, parent it
                    klass, args = [t[0], t[1]]
                    obj = klass.new(*args)
                    obj.parent = @value

                    template_entry_added_hook(obj) || @value << obj
                rescue
                    pp t
                    raise
                end
            end

            super(opts)

            final_initialization_hook
        end

        # Return a field (the Parsel object) by offset into the
        # Structure or by name lookup
        #
        def [](k)
            k = k.intern if k.kind_of? String
            if k.kind_of? Symbol
                @value[self.class.structure_field_names[k]]
            else
                @value[k]
            end
        end

        # Assign to a field. You can pass scalar types and they'll
        # be converted, so struct.name = "foo" works.
        #
        def []=(k, v)
            k = k.intern if k.kind_of? String
            if k.kind_of? Symbol
                @value[self.class.structure_field_names[k]] = v
            else
                @value[k] = v
            end
        end

        # Easy --- delegate to blob
        #
        def capture(str)
            @value.capture(str)
        end

        def before_render_hook(*args); super(*args); end

        # Easy --- delegate to blob
        #
        def to_s(off=nil)
            before_render_hook
            @rendered_offset = off || 0
            @value.to_s(off)
        end

        # A la openstruct/struct --- method calls can be references
        # to field names.
        #
        def method_missing(meth, *args)
            d = self.class.structure_field_names
            m = meth.to_s

            setter = (m[-1].chr == "=") ? true : false
            m = m[0..-2] if setter

            puts "WARNING: assignment to @value as struct field" if setter and m == "value"

            if (i = d[m.intern])
                if setter
                    self[m.intern] = args[0]
                else
                    self[m.intern]
                end
            else
                super(meth, *args)
            end
        end

        def self.with_args(*args, &block)
            if args[0].kind_of? Hash
                name = nil
                opts = args[0]
            else
                name = args[0]
                opts = args[1]
            end

            opts ||= {}
            block.call(name, opts)
        end
    end
end

# Read me for the current list of field definitions shortcuts.
load File.dirname(__FILE__) + '/structure_shortcuts.rb'

