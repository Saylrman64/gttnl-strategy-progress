module Progressive::ProjectPatchGttnlStrategyProgress
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)
  end
  
  module InstanceMethods
    def calculate_score_for_field(score_field)
      score_issue_status_settings = Setting.plugin_gttnl_bsc["issue_status_for_score"] rescue nil
      total = score_field.format.total_for_scope(score_field,issues.where.not(:fixed_version_id=>nil).where(:status_id=>score_issue_status_settings))
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
