#!/usr/bin/env ruby

# == Introduction
# This is yet another binary formatter for Ruby; compare to bindata,
# bitstruct, or pack/unpack.
#
# Read in this order:
# * Parsel
# * Number
# * Str
# * Blob
# * Structure

module Ruckus
end

require 'extensions/extensions'

%w[ parsel number ip str choice null blob filter structure dictionary
    mutator vector mac_addr enum time_t selector ].each do |f|
    require 'ruckus/' + f
end
