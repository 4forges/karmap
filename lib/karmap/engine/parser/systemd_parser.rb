class SystemdParser

  def self.systemctl_show(service:, user: false, properties: nil)
    user_param = user ? '--user' : ''
    property_param = properties.present? ? "--property=#{properties.join(',')}" : ''
    output = `systemctl #{user_param} show #{property_param} #{service}`
    return output.split("\n").map{|l| l.split('=',2)}.to_h
  end

  STATUS_PROPERTIES = ['Loaded', 'Active', 'Main PID']

  def self.systemctl_status(service:, user: false)
    user_param = user ? '--user' : ''
    service_param = "'#{service}'"
    output = `systemctl #{user_param} status #{service_param}`
    output = output.split("\n")
    status = {}
    current_service = ''
    output.each do |line|
      if line.start_with?('●')
        current_service = line[2..-1]
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
