#!/opt/puppetlabs/puppet/bin/ruby
require 'open3'
require 'json'

output, _stderr, _status = Open3.capture3('puppet resource service puppet')
if status != 0
  puts stderr
  exit 1
end

# This seems...dumb
enabled = false
running = false
output.split("\n").each do |line|
  if line =~ %r{^  enable => '#{target_service_enabled}',$}
    enabled = true
  end
  if line =~ %r{^  ensure => '#{target_service_running}',$}
    running = true
  end
end

state = running ? 'running' : 'stopped'
out = { 'state' => { 'enabled' => enabled,
                     'ensure' => state },
        'type' => 'Service',
        'title' => 'puppet' }
puts out.to_json
