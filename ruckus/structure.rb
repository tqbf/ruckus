# === Structures are blobs with symbol tables.
#
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
        @@templates ||= {}
        @@names ||= {}
        @@callbacks ||= Hash.new {|h, k| h[k] = []}
        @@initializers ||= Hash.new {|h, k| h[k] = []}

        (class << self;self;end).class_eval {

            # Rules for converting classmethod calls to types:
            # 1.   Convert to uppercase
            # 2.   If last arg is an opts hash, pull :from, use as module
            # 3.   Otherwise, use Ruckus as the module
            # 4.   Look up the uppercased name in the module
            # 5.   Call #new on it (when the object is instantiated)
            #
            def method_missing(meth, *args)
                if meth.to_s =~ /^relate_(.*)/
                    return relate($1.intern, *args)
                end

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

            def relate(attr, field, opts={})
                opts[:through] ||= :value
                raise "need a valid field to relate" if not field
                raise "need :to argument" if not opts[:to]

                @@initializers[self] << lambda do
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
        }

        # holy crap I need to figure this metaclass stuff out
        def self.at_create(arg=nil, &block)
            if not block_given?
                raise "need a callback function" if not arg
                arg = arg.intern if not arg.kind_of? Symbol
                block = lambda { send(arg) }
            end

            @@initializers[self] << block
        end

        def self.override(field, val)
            at_create { self[field] = val }
        end

        def self.before_render(arg=nil, &block)
            if not block_given?
                raise "need a callback function" if not arg
                arg = arg.intern if not arg.kind_of? Symbol
                block = lambda { send(arg) }
            end

            @@callbacks[self] << block
        end

        # If you have an actual class reference, you can just pass
        # it to <tt>add</tt>, as in:
        #
        #   add(HeaderStructure, :name => :header)
        #
        def self.add(*args)
            raise "no class" if not args[0]
            @@templates[self] ||= []
            @@templates[self] << [args[0], args[1..-1]]
        end

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

            @before_callbacks = []
            @initializers = []
            template = []
            rec = lambda do |x|
                # Walk up until we find Structure, which should
                # never have fields, collecting field definitions

                if x.superclass.inherits_from? Structure
                    rec.call(x.superclass)
                end

                @before_callbacks.concat((@@callbacks[x]||[]))
                @initializers.concat((@@initializers[x]||[]))
                template.concat @@templates[x] if @@templates[x]
            end
            rec.call self.class

            # If this is the first time we're seeing this definition,
            # we also need to convert field names into blob offsets.
            #
            if not @@names[self.class]
                @@names[self.class] = Hash.new
                pop = true
            else
                pop = false
            end

            template.each do |t|
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

                @@names[self.class][name] = @value.count if (name and pop)
                begin
                    klass = t[0]
                    args = t[1]
                    obj = klass.new(*args)
                    obj.parent = @value
                    found = false

                    @value.each_with_index do |x,i|
                        if x.try(:name) == obj.try(:name)
                            found = i
                            break
                        end
                    end
                    @value << obj if not found

                    if found
                        @@names[self.class][name] = found
                        @value[found] = obj
                    end
                rescue
                    pp t
                    raise
                end
            end

            super(opts)

            @initializers.each {|cb| self.instance_eval(&cb)}
        end

        def before_render
            @before_callbacks.each {|cb| self.instance_eval(&cb)}
        end

        # Return a field (the Parsel object) by offset into the
        # Structure or by name lookup
        #
        def [](k)
            k = k.intern if k.kind_of? String
            if k.kind_of? Symbol
                @value[@@names[self.class][k]]
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
                @value[@@names[self.class][k]] = v
            else
                @value[k] = v
            end
        end

        # Easy --- delegate to blob
        #
        def capture(str)
            @value.capture(str)
        end

        # Easy --- delegate to blob
        #
        def to_s(off=nil)
            before_render
            @rendered_offset = off || 0
            @value.to_s(off)
        end

        # A la openstruct/struct --- method calls can be references
        # to field names.
        #
        def method_missing(meth, *args)
            d = @@names[self.class]
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

        class ValueProxy
            def initialize(target); @t = target; end
            def method_missing(meth, *args)
                if meth.to_s.ends_with? "="
                    @t.send(meth, *args)
                else
                    @t.send(meth).send(:value)
                end
            end
        end

        class NodeProxy
            def initialize(target); @t = target; end
            def method_missing(meth, *args)
                if meth.to_s.ends_with? "="
                    @t.send(meth, *args)
                else
                    @t[meth]
                end
            end
        end

        def v; ValueProxy.new(self); end
        def n; NodeProxy.new(self); end

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

