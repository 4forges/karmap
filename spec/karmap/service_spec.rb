# frozen_string_literal: true

require 'spec_helper'

describe Karma::Service do
  before(:each) do
    Karma.reset_engine_instance
    Karma.engine = 'systemd'
  end
  before(:each) { Karma.engine_instance.export_service(TestService) }
  after(:each) do
    status = Karma.engine_instance.show_all_services
    status.values.each do |s|
      Karma.engine_instance.stop_service(s.pid)
    end
  end
  after(:each) { Karma.engine_instance.remove_service(TestService) }

  it 'service calls lifecycle callbacks' do
    Karma.engine_instance.start_service(TestService)
    wait_for { File.exist?('spec/log/TestService-before_start.log') }.to be_truthy
    wait_for { File.exist?('spec/log/TestService-after_start.log') }.to be_truthy
    wait_for { File.exist?('spec/log/TestService-perform.log') }.to be_truthy

    status = Karma.engine_instance.show_service(TestService)
    pid = status.values[0].pid

    Karma.engine_instance.stop_service(pid)
    wait_for { File.exist?('spec/log/TestService-before_stop.log') }.to be_truthy
    wait_for { File.exist?('spec/log/TestService-after_stop.log') }.to be_truthy
    wait_for { Karma.engine_instance.show_service(TestService) }.to be_empty
  end
end
