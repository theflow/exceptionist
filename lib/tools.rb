require 'boot'
require './config'

module Exceptionist
  class Remover
    def self.run(uber_key)
      UberException.find(uber_key).forget!
    end
  end
end
