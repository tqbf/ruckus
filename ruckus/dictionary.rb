# === A collection of objects of which only one is active at any particular time

module Ruckus
  # A Dictionary is a collection of data objects of which only one is
  # active at any particular time. This class extends and provies a simplified
  # front-end for Choice.
  #
  class Dictionary < Choice
    attr_accessor :dict, :selection

    # Initializes a new Dictionary object.
    # Parameters may be provided at initialisation to control the behaviour
    # of an object. These params are:
    #
    #  dict       An indexable (generally hash or array) object with indexed
    #             values mapped to the possible data objects. (see notes below)
    #             Any indexable object using the [] method can be used,
    #             provided that 'selection' returns a valid index. If a type
    #             is to have parameters passed to it, then it should be
    #             provided as [type, hash_params]
    #
    #  selection    An index into :dict which specifies the currently
    #             active choice.
    #
    #  default    An optional parameter specifying the default class
    #             to capture to.
    #
    # A selection may be any of the following:
    #
    #  - Immediate Value:
    #    An immediate value to be used as the index. Fixnum
    #
    #  - Symbol:
    #    A symbol which will be will be searched with 'find_tag' from the
    #    root of the parent structure. The value of the tagged element is used
    #    as the index.
    #     - By default a type symbol will be converted to an immediate name and
    #     pulled from the Ruckus namespace.
    #     - To specify another namespace, use the :dict_from parameter as in
    #      ":dict_from => Name::Space". A :dict_from namespace can be
    #      set globally or overidden as a per choice parameter.
    #
    #  - Proc/Lambda:
    #    The lambda or proc is called and passed the following parameters:
    #
    #        'buf'  - The capture buffer
    #        'this' - A reference to the current choice structure.
    #
    #    The lambda must return either of the following
    #
    #        An immediate value for the index to select
    #
    #        An array pair consisting of the immediate value and sub-string
    #        buffer for the selection.
    #
    #        NOTE: The latter form allows the proc to perform its own internal
    #        'captures'. The proc is expected to remove (slice!) any contents
    #        from the original buffer for whatever extractions are made with
    #        'capture'.
    #
    def initialize(opts={})
      @dict = (opts[:dict] || [])
      @selection = (opts[:selection] || nil)
      @dict_from = (opts[:dict_from] || Ruckus)
      @default = opts[:default]

      # This lambda is passed to the 'choice' superclass to provide
      # all the dictionary functionality.
      block = lambda do |buf, this|
        lambuf = nil
        case @selection
        when Symbol
          sel = (x=this.root.find_tag(@selection) and x.value)
        when Proc
          sel, lambuf = @selection.call(buf,this)
        else
          sel = @selection
        end

        if (k = @dict[sel]) or (k = @default)
          ksym, *args = k
          return buf unless ksym

          unless args[-1].kind_of?(Hash) and nsp=args[-1][:dict_from]
            nsp = @dict_from
          end

          klass = if (ksym.kind_of? Class or ksym.kind_of? Module)
                    ksym
                  else
                    ksym.to_s.const_lookup(nsp) or return(buf)
                  end

          choice = klass.new(*args)
          choice.parent = this.value.parent
          this.value = choice

          if not lambuf.nil?
            return buf if x=this.value.capture(lambuf) and x.empty?
          else
            this.value.capture(buf)
          end
        end
      end

      super( opts.merge(:block => block) )
    end

  end # class Dictionary

  class Structure
    # Convenience alias for 'dictionary'. First arg is "name", all others
    # are passed directly into 'new'
    def self.dict(*args)
      with_args(*args) {|name, opts| dictionary opts.merge(:name => name)}
    end
  end

end # module Ruckus
