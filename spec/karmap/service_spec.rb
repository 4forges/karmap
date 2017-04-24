# encoding: UTF-8

require 'spec_helper'

describe Karma::Service do

  let(:service) { TestService.new }

  before(:each) { Karma.engine_instance.export_service(service) }
  after(:each) do
    status = Karma.engine_instance.show_all_services
    status.values.each do |s|
      Karma.engine_instance.stop_service(s.pid)
      sleep(1)
    end
  end

  it 'service calls lifecycle callbacks' do
    Karma.engine_instance.start_service(service)
    wait_for{File.exists?('spec/log/testservice-before_start.log')}.to be_truthy
    wait_for{File.exists?('spec/log/testservice-after_start.log')}.to be_truthy
    wait_for{File.exists?('spec/log/testservice-perform.log')}.to be_truthy

    status = Karma.engine_instance.show_service(service)
    pid = status.values[0].pid

    Karma.engine_instance.stop_service(pid)
    wait_for{File.exists?('spec/log/testservice-before_stop.log')}.to be_truthy
    wait_for{File.exists?('spec/log/testservice-after_stop.log')}.to be_truthy
    wait_for{Karma.engine_instance.show_service(service)}.to be_empty
  end

end
