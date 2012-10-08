require 'webmachine'
require './search_resource'

# Create an application which encompasses routes and configuration
SearchApp = Webmachine::Application.new do |app|
  app.routes do
    # Point all URIs at the SearchResource class
    add ['*'], SearchResource
  end

  app.configure do |config|
    config.ip = '127.0.0.1'
    config.port = ENV['PORT'] || 3000
    # config.adapter = :Mongrel
  end
end

SearchApp.run
