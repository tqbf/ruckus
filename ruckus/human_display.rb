## Human display methods
# Here are various methods for ruckus base types to display human-readable 
# data representations. No particular attempt is made at efficiency. These 
# are for dissectors, analysis, debugging, etc...

module Ruckus
  Blob.class_eval do
    def to_human(indent=nil)
      indent ||= ""
      vals = []
      vals << "#{indent}#{name.to_s} = " if @name
      indent += "  "
      vals += @value.map do |it|
        if it.respond_to?(:format) and it.format.kind_of? Proc
          "#{indent}#{it.name} = #{it.format.call(it)}"
        elsif it.respond_to?(:to_human)
          it.to_human(indent)
        else
          "#{indent}#{it.name} = #{it.value}"
        end
      end
    end
  end


  Structure.class_eval do
    def to_human(indent=nil)
      "#{ indent || '' }#{self.class}".to_a + super(indent)
    end
  end


  IP.class_eval do
    def to_human(indent=nil)
      s = to_s
      "#{ indent || '' }#{name.to_s} = #{s[0]}.#{s[1]}.#{s[2]}.#{s[3]}"
    end
  end


  Choice.class_eval do
    def to_human(indent=nil)
      indent ||= ''
      head = "#{indent}#{name.to_s} = " 
      if (val=@value.to_human(indent)).kind_of?(Array) and @name
        val.unshift head
      else
        head + val.to_s.strip
      end
    end
  end


  Str.class_eval do
    def to_human(indent=nil)
      "#{ indent || '' }#{@name} = " +
      (@value.empty? ? "<empty>" : "\n%%\n#{@value.hexdump(:out => StringIO.new)}%%\n")
    end
  end


  Number.class_eval do
    def to_human(indent=nil)
      if self.value.kind_of?(Numeric) then
        "#{ indent ||'' }#{@name} = %d (0x%x)" %[ self.value, self.value ]
      else
        "#{ indent ||'' }#{@name} = #{self.value}"
      end
    end
  end


  Null.class_eval do
    def to_human(indent=nil)
      "#{ indent || '' }#{@name} = <nil>"
    end
  end
end

