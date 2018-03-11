resource_name :machine_name

property :hostname, String, desired_state: true, coerce: proc { |name| conform_to_rfc1034(name) }, required: true, name_property: true
property :computer_name, String, desired_state: true
property :local_hostname, String, desired_state: true, coerce: proc { |name| conform_to_rfc1034(name) }
property :netbios_name, String, desired_state: false, coerce: proc { |name| conform_to_rfc1034(name)[0, 15].upcase }
property :dns_domain, String, desired_state: false, default: ''

load_current_value do
  hostname current_hostname
  dns_domain current_dns_domain
  computer_name get_name('ComputerName')
  local_hostname get_name('LocalHostName')
end

action :set do
  converge_if_changed :hostname do
    converge_by "set Hostname to #{new_resource.hostname}" do
      full_hostname = [new_resource.hostname, new_resource.dns_domain].join('.')
      execute [scutil, '--set', 'HostName', full_hostname] do
        notifies :reload, 'ohai[reload ohai]'
      end
    end
  end

  converge_if_changed :computer_name do
    property_is_set?(:computer_name) ? new_resource.computer_name : new_resource.computer_name = new_resource.hostname
    converge_by "set ComputerName to #{new_resource.computer_name}" do
      execute [scutil, '--set', 'ComputerName', new_resource.computer_name] do
        notifies :reload, 'ohai[reload ohai]'
      end
    end
  end

  converge_if_changed :local_hostname do
    property_is_set?(:local_hostname) ? new_resource.local_hostname : new_resource.local_hostname = new_resource.hostname
    converge_by "set LocalHostName to #{new_resource.local_hostname}" do
      execute [scutil, '--set', 'LocalHostName', new_resource.local_hostname] do
        notifies :reload, 'ohai[reload ohai]'
      end
    end
  end

  property_is_set?(:netbios_name) ? new_resource.netbios_name : new_resource.netbios_name = new_resource.hostname
  plist 'NetBIOSName' do # converge_if_changed is not needed since `plist` is already idempotent
    path '/Library/Preferences/SystemConfiguration/com.apple.smb.server.plist'
    entry 'NetBIOSName'
    value new_resource.netbios_name
    encoding 'us-ascii'
    notifies :run, 'ruby_block[sleep ten seconds]'
  end

  service 'com.apple.smb.preferences' do
    action :nothing
    notifies :reload, 'ohai[reload ohai]'
  end

  ohai 'reload ohai' do
    action :nothing
  end

  ruby_block 'sleep ten seconds' do
    block do
      sleep 10
    end
    action :nothing
    notifies :restart, 'service[com.apple.smb.preferences]', :immediately
  end
end
