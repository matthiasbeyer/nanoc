# encoding: utf-8

module Nanoc::Helpers

  module HelperUtils

    # Helper method for helpers to generate nice error messages. 
    #
    # @param [Class] klass the Class, to check the object for
    # @param [Object] obj the Object to check.
    # @param [Hash] opts Options
    #
    # @option opts [Hash] :method The name of the method which ran this check
    # @option opts [Hash] :format The format of the arguments
    #
    # @example Checking for a Hash which has a required entry 
    #
    #   def multiply_by_two(h)
    #     awaits(Hash, h, {:format => {:my_parameter => Integer, 
    #       :method => #     __method__})
    #     h[:my_parameter] * 2
    #   end
    #
    # @example Checking for a Integer
    #
    #   def mutliply_by_two_without_hash(i)
    #     awaits(Integer, i, {:format => Integer, :method => __method__})
    #     i*2
    #   end
    #
    def awaits(klass, obj, opts = Hash.new)
      blk = lambda { |k| obj.is_a? k }
      cond = (klass.is_a?(Array) ? klass : [klass] ).map(&blk).any?

      if not cond
        errstr = "Waiting for #{(klass.is_a?(Array) ? "one out of #{klass}" : klass.name)}"
        errstr << " in #{opts[:method]} but" if opts[:method]
        errstr << " was #{obj.class.name}"
        errstr << " with format #{opts[:format]}" if opts[:format]

        raise Nanoc::Errors::GenericTrivial.new(errstr) if opts[:raise]
        errstr
      end
    end

  end

end


require 'nanoc/helpers/blogging'
require 'nanoc/helpers/breadcrumbs'
require 'nanoc/helpers/capturing'
require 'nanoc/helpers/filtering'
require 'nanoc/helpers/html_escape'
require 'nanoc/helpers/link_to'
require 'nanoc/helpers/rendering'
require 'nanoc/helpers/tagging'
require 'nanoc/helpers/text'
require 'nanoc/helpers/xml_sitemap'
