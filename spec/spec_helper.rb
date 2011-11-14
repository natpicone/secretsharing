# -*- encoding: utf-8 -*-

require 'rubygems'
require 'bundler'
Bundler.setup

# must be the first code included or coverage tests won't work.
begin
  require 'simplecov'
  SimpleCov.start
  SimpleCov.add_filter "/specs/"
rescue LoadError => e
  # skip simplecov if it can't be loaded
end
# Allow 'require_relative' to work in Ruby 1.8.x and 1.9.x (where
# 'require_relative' is the current method.
#
# tested w/ RVM installed MRI Ruby 1.8.7, 1.9.2, 1.9.3 using:
#
#   rvm 1.8.7@secretsharing,1.9.2@secretsharing,1.9.3@secretsharing do bundle install
#   rvm 1.8.7@secretsharing,1.9.2@secretsharing,1.9.3@secretsharing do rake test
#

require File.expand_path("../../lib/secretsharing", __FILE__)

require 'minitest/spec'
require 'minitest/autorun'
