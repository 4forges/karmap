$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'karmap'
require 'karmap/models/test_service'
require 'rspec'

def example_folder
  '~/Karma/spec'
end

def resource_path(filename)
  File.expand_path("../resources/#{filename}", __FILE__)
end

def example_export_file(filename)
  File.read(File.expand_path(resource_path("export/#{filename}"), __FILE__))
end

RSpec.configure do |config|

  config.color = true

  config.order = 'rand'

end