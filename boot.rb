require 'rubygems'

require 'time'
require 'zlib'
require 'redis'
require 'yajl'

require 'lib/models/project'
require 'lib/models/uber_exception'
require 'lib/models/occurrence'

require 'lib/exceptionist'


begin
  require 'config'
rescue LoadError
  puts "\n  Valid config.rb missing, please do a:"
  puts "  cp config.rb.example config.rb\n\n"
  exit
end
