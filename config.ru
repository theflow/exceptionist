begin
  require 'config'
rescue LoadError
  puts "\n  Valid config.rb missing, please do a:"
  puts "  cp config.rb.example config.rb\n\n"
  exit
end

run ExceptionistApp
