module Progressive::ApplicationHelperPatch
  def self.included(base) # :nodoc:
    base.class_eval do

      def progressive_setting(key)
        if key == :sort_project_by
          sort_options = get_sort_custom_fields.collect(&:id)
          if Redmine::Plugin.registered_plugins.has_key?(:gttnl_bsc)
            if Setting["plugin_gttnl_bsc"] && Setting["plugin_gttnl_bsc"]["show_scorecard"] == "1" && Setting["plugin_gttnl_bsc"]["cf_for_score"].present?
              sort_options << ("sort_by_score")
            end
          end
          if request.params[:progressive]
            session[:sort_project_by] = sort_options.map(&:to_s).include?(request.params[:sort_project_by]) ? request.params[:sort_project_by] : "default"
          elsif session[:sort_project_by]
            session[:sort_project_by] = sort_options.map(&:to_s).include?(session[:sort_project_by]) ? session[:sort_project_by] : "default"
          else
            session[:sort_project_by] = "default"
          end 
        else
          if request.params[:progressive]
            session[:progressive] = true
            session[key] = request.params[key]
          elsif session[:progressive]
            session[key]
          else
            Setting.plugin_gttnl_strategy_progress[key.to_s]
          end
        end
      end

      def progressive_setting?(key)
        progressive_setting(key).present?
      end

      def get_sort_custom_fields
        cf_ids = []
        cf_ids << Setting.plugin_gttnl_strategy_progress[:sort_project_custom_field] 
        cf_ids << Setting.plugin_gttnl_strategy_progress[:sort_version_custom_field]
        CustomField.visible.where(:id=> cf_ids.flatten) rescue []
      end

      def get_sort_options
        sort_options = [[l(:label_default),"default"]]
        sort_custom_fields = get_sort_custom_fields
        sort_custom_fields.each{|x|sort_options << [x.name,x.id]}
        if Redmine::Plugin.registered_plugins.has_key?(:gttnl_bsc)
          if Setting["plugin_gttnl_bsc"] && Setting["plugin_gttnl_bsc"]["show_scorecard"] == "1" && Setting["plugin_gttnl_bsc"]["cf_for_score"].present?
            sort_options << [l(:sort_by_score),"sort_by_score"]
          end
        end
        sort_options
      end

      def get_custom_fields_to_display(field_class)
        cf_settings = Setting.plugin_gttnl_strategy_progress["sort_#{field_class}_custom_field"] rescue nil
        if cf_settings.present?
          clause = cf_settings.map{|x| "id = #{x} desc" }.join(",")
          case field_class
          when "project"
            ProjectCustomField.visible.where(:id=>cf_settings).order(clause) rescue []
          when "version"
            VersionCustomField.visible.where(:id=>cf_settings).order(clause) rescue []
          else []
          end  
        else
          []
        end
      end
    end
  end
end

unless ApplicationHelper.include? Progressive::ApplicationHelperPatch
  ApplicationHelper.send(:include, Progressive::ApplicationHelperPatch)
end