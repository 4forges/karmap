require 'spec_helper'

describe Karma::Engine::Systemd do

  let(:service) { TestService.new }

  it 'spawns 2 threads' do
    running = ::Thread.new do
      service.run
    end
    wait_for(service.running_thread_count).to eq(2)
    running.exit
  end

  it 'spawns more threads after config update' do
    running = ::Thread.new do
      service.run
    end
    wait_for(service.running_thread_count).to eq(2)
    service.update_thread_config(num_threads: 3)
    sleep(1)
    expect(service.running_thread_count).to eq(3)
    running.exit
  end

  it 'kills threads after config update' do
    running = ::Thread.new do
      service.run
    end
    wait_for(service.running_thread_count).to eq(2)
    service.update_thread_config(num_threads: 1)
    sleep(1)
    expect(service.running_thread_count).to eq(1)
    running.exit
  end

end
