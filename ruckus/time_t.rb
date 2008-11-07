
module Ruckus
  class TimeT < Number
    def initialize(opts={})
      opts[:width] ||= 32
      super(opts)
    end

    def to_human(indent="")
      "#{indent}#{@name} = #{@value.to_hex} (#{time})"
    end

    def utc(*args)
      @value=( Time.utc(*args) ).to_i
    end
    alias :gm :utc

    def local(*args)
      @value=( t=Time.local(*args)).to_i
    end

    def time
      Time.at(@value)
    end
  end
end
