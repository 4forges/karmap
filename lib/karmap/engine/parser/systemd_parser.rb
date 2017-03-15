class SystemdParser

  SHOW_PROPERTIES = ['LoadState', 'ActiveState', 'SubState', 'MainPID', 'ExecMainStartTimestamp']

  # Calls systemctl show and returns a hash.
  # Pass an empty array as properties to get all of them (very verbose).
  # Example usage:
  #   SystemdParser.systemctl_show(service: 'ssh')
  #   => {"MainPID"=>"1477", "ExecMainStartTimestamp"=>"Wed 2017-03-15 11:01:59 CET", "LoadState"=>"loaded", "ActiveState"=>"active", "SubState"=>"running"}
  def self.systemctl_show(service:, user: false, properties: SHOW_PROPERTIES)
    user_param = user ? '--user' : ''
    property_param = properties.any? ? "--property=#{properties.join(',')}" : ''
    output = `systemctl #{user_param} show #{property_param} #{service}`
    return output.split("\n").map{|l| l.split('=',2)}.to_h
  end

  STATUS_PROPERTIES = ['Loaded', 'Active', 'Main PID', 'Tasks', 'Memory', 'CPU']

  # Calls systemctl status and returns a structured hash.
  # Accepts wildcards. Example:
  #   SystemdParser.systemctl_status(service: 'test-*@*')
  # Example usage:
  #   SystemdParser.systemctl_status(service: 'ssh')
  #   => {"ssh.service"=>{"Loaded"=>"loaded", "Active"=>"active", "Main PID"=>"1477", "Tasks"=>"1", "Memory"=>"7.0M", "CPU"=>"49ms"}}
  def self.systemctl_status(service:, user: false)
    user_param = user ? '--user' : ''
    service_param = "'#{service}'"
    output = `systemctl #{user_param} status #{service_param}`
    output = output.split("\n")
    status = {}
    current_service = ''
    output.each do |line|
      if line.start_with?('●')
        current_service = line[2..-1].split(' ', 2)[0].strip
        status[current_service] ||= {}
      else
        begin
          attr = line.split(':', 2)
          key = attr[0].strip
          if STATUS_PROPERTIES.include? key
            val = attr[1].split('(', 2)[0].strip
            status[current_service][key] = val
          end
        rescue
        end
      end
    end
    return status
  end

end
