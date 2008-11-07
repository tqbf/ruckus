
module Ruckus
  class Enum < Number
    attr_accessor :enums

    def initialize(opts={})
      super(opts)
      @enums ||= []
      raise "enums must be Enumerable" unless @enums.kind_of? Enumerable
    end

    def to_human(indent="")
      "#{indent}#{@name} = #{@value}(#{@value.to_hex}) [ #{ ((n=lookup)? n : "???").to_s } ]"
    end

    def lookup
      if (o=@enums[@value]).kind_of?(Hash) then o[:name] else o end
    end
  end

  class Structure
    def self.enum16le(*args)
      with_args(*args) {|name, opts| enum name, opts.merge(:width => 16, :endian => :little)}
    end

    def self.enum32le(*args)
      with_args(*args) {|name, opts| enum name, opts.merge(:width => 32, :endian => :little)}
    end

    def self.enum16be(*args)
      with_args(*args) {|name, opts| enum name, opts.merge(:width => 16, :endian => :big)}
    end

    def self.enum32be(*args)
      with_args(*args) {|name, opts| enum name, opts.merge(:width => 32, :endian => :big)}
    end
  end
end

