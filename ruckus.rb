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

module Ruckus;end

require File.dirname(__FILE__) + '/../extensions/extensions'
