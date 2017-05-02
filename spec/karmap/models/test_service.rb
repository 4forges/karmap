# encoding: UTF-8

require 'karmap'

class TestService < Karma::Service

  command 'bundle exec ruby spec/scripts/run_test_service.rb'
  min_running  2
  max_running  5
  port         33000
  num_threads  2

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
