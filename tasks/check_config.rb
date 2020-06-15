#!/opt/puppetlabs/puppet/bin/ruby
require 'open3'
require 'json'

confprint = '/opt/puppetlabs/puppet/bin/puppet config print --render-as json'
output, stderr, status = Open3.capture3(confprint)
if status != 0
  puts stderr
  exit 1
end

config = JSON.parse(output)
out = { '_output' => [{ 'state' => { 'noop' => config['noop'] },
                        'type' => 'Puppetnoop',
                        'title' => 'noop' },
                        { 'state' => { 'runinterval' => config['runinterval'] },
                          'type' => 'Puppetruninterval',
                          'title' => 'runinterval' }]}
puts out.to_json
