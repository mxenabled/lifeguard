require 'rubygems'
require 'bundler'

require 'simplecov'

SimpleCov.start do
  project_name 'lifeguard'
  add_filter '/coverage/'
  add_filter '/doc/'
  add_filter '/pkg/'
  add_filter '/spec/'
  add_filter '/tasks/'
end

Bundler.require(:default, :development, :test)

require 'lifeguard'

# import all the support files
Dir[File.join(File.dirname(__FILE__), 'support/**/*.rb')].each { |f| require File.expand_path(f) }

RSpec.configure do |config|
  config.after(:each) do
    Thread.list.each do |thread|
      thread.kill unless thread == Thread.current
    end
  end
end
