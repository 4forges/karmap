# encoding: UTF-8

require 'spec_helper'

class MockService < Karma::Service

  include Karma::ServiceMessage

  min_running  2
  max_running  5
  port         33100
  auto_restart false

  def perform
    File.open("#{folder}/#{name}-#{__method__}.log", 'w') { |file| file.puts("process #{$$} :: thread #{Thread.current.object_id} :: method #{__method__}") }
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
    'log'
  end

end
