require 'rubygems'

require 'time'
require 'zlib'
require 'redis'
require 'yajl'

require 'models/project'
require 'models/uber_exception'
require 'models/occurrence'

require 'models/exceptionist'


begin
  require 'config'
rescue LoadError
  puts "\n  Valid config.rb missing, please do a:"
  puts "  cp config.rb.example config.rb\n\n"
  exit
end
