module Exceptionist
  class Occurrence < Model
    attr_accessor :exception_message, :session, :action_name,
                  :parameters, :url, :occurred_at, :exception_backtrace,
                  :controller_name, :environment, :exception_class,
                  :framework, :language, :application_root, :id, :uber_key

    def title
      "#{exception_class} in #{controller_name}##{action_name}"
    end

    def occurred_at=(time_as_string)
      @occurred_at = DateTime.parse(time_as_string)
    end
  end
end
