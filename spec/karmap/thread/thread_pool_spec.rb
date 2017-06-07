# encoding: UTF-8

require 'spec_helper'

describe Karma::Thread::ThreadPool do

  # before(:each) do
  #   Karma.reset_engine_instance
  #   Karma.engine = 'system_raw'
  # end
  #
  # def set_num_threads(service, num)
  #   s = TCPSocket.new('127.0.0.1', service.instance_port)
  #   s.puts({ log_level: 0, num_threads: num }.to_json)
  #   s.close
  # end
  #
  # it 'spawns 2 threads and change at runtime' do
  #   service = TestService.new
  #   ::Thread.new do
  #     service.run
  #   end
  #   wait_for {service.running_thread_count}.to eq(2)
  #
  #   set_num_threads(service, 3)
  #   wait_for {service.running_thread_count}.to eq(3)
  #
  #   set_num_threads(service, 1)
  #   wait_for {service.running_thread_count}.to eq(1)
  #
  #   service.stop
  #   wait_for {service.running_thread_count}.to eq(0)
  # end

end
