# instead of dealing with .value directly, this class exposes 'set' and 
# 'display' methods for handling @value as a mac address string.
class MacAddr < Ruckus::Str
  def initialize(opts={})
    opts[:size] = 6
    super(opts)
    @width = 48
  end

  # mac address may be specified as either
  #  aa-bb-cc-dd-ee-ff
  #  or
  #  aa:bb:cc:dd:ee:ff
  def set(val)
    unless m=/^([0-9a-f]{2})([:-]?)([0-9a-f]{2})\2([0-9a-f]{2})\2([0-9a-f]{2})\2([0-9a-f]{2})\2([0-9a-f]{2})$/i.match(val)
      raise "argument must be a mac_addr string as in aa:bb:cc:dd:ee:ff"
    end
    self.value = [$1,$3,$4,$5,$6,$7].join('').dehexify
  end

    
  def display
    self.value.split('').map {|x| x.hexify}.join(':')
  end

  def to_human(indent=nil)
    indent ||= ""
    "#{indent}#{name} = #{self.display}"
  end
end

