# frozen_string_literal: true

require 'karmap'

class TestService < Karma::Service
  port         33000
  min_running  1
  max_running  1
  num_threads  2

  def self.command
    travis_build_dir = ENV['TRAVIS_BUILD_DIR'] || '.'
    File.open('./test_service.run', 'w') do |file|
      file.write("cd #{travis_build_dir}\n")
      file.write("bundle exec ruby spec/scripts/run_test_service_#{Karma.engine}.rb")
    end
    File.chmod(0o755, './test_service.run')
    './test_service.run'
  end

  def perform
    msg = "#{Time.now} :: process #{$$} :: thread #{Thread.current.object_id} :: method #{__method__}"
    File.open("#{folder}/#{name}-#{__method__}.log", 'w') { |file| file.puts(msg) }
    Thread.current[:logger].info { msg } rescue false
  end

  def before_start
    File.open("#{folder}/#{name}-#{__method__}.log", 'w') { |file| file.puts("process #{$$} :: thread #{Thread.current.object_id} :: method #{__method__}") }
  end

  def after_start
    File.open("#{folder}/#{name}-#{__method__}.log", 'w') { |file| file.puts("process #{$$} :: thread #{Thread.current.object_id} :: method #{__method__}") }
  end

  def before_stop
    File.open("#{folder}/#{name}-#{__method__}.log", 'w') { |file| file.puts("process #{$$} :: thread #{Thread.current.object_id} :: method #{__method__}") }
  end

  def after_stop
    File.open("#{folder}/#{name}-#{__method__}.log", 'w') { |file| file.puts("process #{$$} :: thread #{Thread.current.object_id} :: method #{__method__}") }
  end

  private ##########

  def folder
    Karma.log_folder
  end
end
