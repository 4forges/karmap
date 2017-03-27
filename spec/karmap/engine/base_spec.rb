# encoding: UTF-8

require 'spec_helper'

describe Karma::Engine::Base do

  let(:service) { TestService.new }
  let(:engine) { Karma.engine_class.new }

  before(:each) { engine.export_service(service) }
  after(:each) do
    status = engine.show_all_services
    status.values.each do |s|
      engine.stop_service(s.pid)
      sleep(1)
    end
  end

  it 'build service status message' do
    engine.start_service(service)
    wait_for {engine.show_service(service)}.to_not be_empty
    status = engine.show_service(service)
    pid = status.values[0].pid
    message = engine.get_process_status_message(service, pid)
    expect(message.service).to eq('karmat-testservice')
    expect(message.pid).to eq(pid)
    expect(message.status).to eq('running')

    engine.stop_service(pid)
    wait_for{engine.show_service(service)}.to be_empty
    message = engine.get_process_status_message(service, pid)
    expect(message.status).to eq('dead')
  end

end
