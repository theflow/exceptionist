class AbstractModel

  def to_hash
    self.instance_variables.each_with_object({}) do |var, hash|
      value = self.instance_variable_get(var);
      value = Helper.es_time(value) if value.is_a?(Time)
      hash[var.to_s.delete("@")] = value
    end
  end
end
