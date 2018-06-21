module Progressive::ProjectPatchGttnlStrategyProgress
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)
  end
  
  module InstanceMethods
    def calculate_score(score_field)
      total = score_field.format.total_for_scope(score_field,issues)
      total = map_total_score(total) {|t| score_field.format.cast_total_value(score_field, t)}
    end

    def map_total_score(total, &block)
      if total.is_a?(Hash)
        total.keys.each {|k| total[k] = yield total[k]}
      else
        total = yield total
      end
      total
    end
  end
end

unless Project.include? Progressive::ProjectPatchGttnlStrategyProgress
  Project.send(:include, Progressive::ProjectPatchGttnlStrategyProgress)
end
