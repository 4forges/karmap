require 'karmap'

module Karma::FileHelper
  def self.write_file(filename, contents)
    Karma.logger.debug { "writing: #{filename}" }
    File.open(filename, 'w') do |file|
      file.puts contents
    end
  end
end
