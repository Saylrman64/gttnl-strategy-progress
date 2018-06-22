module Progressive::ProjectsHelperPatch
  def self.included(base) # :nodoc:
    base.class_eval do

      def render_project_hierarchy_with_progress_bars(projects)
        cf_for_sorting = get_field_for_sort
        if projects.present? && cf_for_sorting.present?
          case cf_for_sorting.class.to_s
          when "ProjectCustomField"
            sort_by_project_custom_field(projects,cf_for_sorting)
          when "VersionCustomField"
            sort_by_version_custom_field(projects,cf_for_sorting)
          else
            if cf_for_sorting == "sort_by_score"
              sort_by_score_value(projects)
            else
              render_nested_view(projects)
            end
          end
        else
          render_nested_view(projects)
        end
      end

      def sort_by_score_value(projects)
        if Setting["plugin_gttnl_bsc"] && Setting["plugin_gttnl_bsc"]["cf_for_score"].present?   
          project_score = {}
          score_sorted_projects = []
          projects.each do |project|
            project_score[project] = 0
            project_fields = project.all_issue_custom_fields.where(:id=>Setting["plugin_gttnl_bsc"]["cf_for_score"]) rescue []
            project_fields.each do |cf|
              project_score[project]+= project.calculate_score(cf)
            end
          end
          score_sorted_projects = project_score.sort{|a,b| b[1]<=>a[1]}.collect{|x|x[0]}
          render_project_cf_sorted_list(score_sorted_projects)
        else
          render_nested_view(projects)
        end
      end
      #sorts project as per project custom field value
      def sort_by_project_custom_field(projects,cf_for_sorting)
        sort_criteria = Setting.plugin_gttnl_strategy_progress["project_sort_order"]
        sort_criteria = "asc" if sort_criteria.nil?
        default_project_sort = Setting.plugin_gttnl_strategy_progress["default_project_sort"]
        default_project_sort = "name" if default_project_sort.nil?
        project_ids = projects.collect(&:id)
        sorted_projects = Project.joins(:custom_values).where(projects:{id: project_ids},custom_values:{custom_field_id: cf_for_sorting.id}).where("custom_values.value <> ''").order("STR_TO_DATE(custom_values.value, '%Y-%m-%d') #{sort_criteria}").uniq
        project_without_values = projects - sorted_projects.to_a
        project_without_values.sort_by!(&default_project_sort.to_sym)
        render_project_cf_sorted_list(sorted_projects+project_without_values)
      end

      #sorts versions as per version custom field value
      def sort_by_version_custom_field(projects,cf_for_sorting)
        sort_criteria = Setting.plugin_gttnl_strategy_progress["project_sort_order"]
        sort_criteria = "asc" if sort_criteria.nil?
        default_version_sort = Setting.plugin_gttnl_strategy_progress["default_project_sort"]
        default_version_sort = "name" if default_version_sort.nil?
        project_ids = projects.collect(&:id)
        visible_versions = Version.visible
        sorted_versions =  visible_versions.joins(:custom_values).where(versions:{project_id: project_ids},custom_values:{custom_field_id: cf_for_sorting.id}).where("custom_values.value <> ''").order("STR_TO_DATE(custom_values.value, '%Y-%m-%d') #{sort_criteria}").uniq
        unsorted_versions = (visible_versions - sorted_versions).sort_by(&default_version_sort.to_sym)
        render_version_cf_sorted_list(sorted_versions+unsorted_versions)
      end

      #renders project list sorted by version custom field value
      def render_version_cf_sorted_list(versions)
        cf_values_to_display = get_custom_fields_to_display("version")
        score_to_display = false
        if Redmine::Plugin.registered_plugins.has_key?(:gttnl_bsc)
          if Setting["plugin_gttnl_bsc"] && Setting["plugin_gttnl_bsc"]["show_scorecard"] == "1" && Setting["plugin_gttnl_bsc"]["cf_for_score"].present?
            score_to_display = true
          end
        end
        s = '<ul class="projects root">'
        versions.each do |version|
          project = version.project
          project.extend(Progressive::ProjectDecorator)
          s << '<li class="root"><div class="root">'
          s <<  link_to(version.name,version_path(version),:class => 'version-text') + ' : '
          s << '<span class="version-parent-project">' + l(:label_parent_project) + ' :  ' + '</span>'
          s << '<span class="version-project">' + link_to_project(project, {}) + '</span>'
          if version.description.present?
            s << '<div class="wiki description"><strong>' + truncate(version.description,length: 90) + '</strong></div>'
          end
          if version.open?
            if version.description.present?
              s << '<div style="margin-top:5px;padding-left:5px;">'
            else
              s << '<div style="margin-top:20px;padding-left:5px;">'
            end
            if (version.open_issues_count > 0)
              s << '<span class="progressive-project-issues">'
              s << l(:label_issue_plural) + ': ' +
              link_to(l(:label_x_open_issues_abbr, :count => version.open_issues_count), :controller => 'issues', :action => 'index', :project_id => project,:status_id => 'o', :fixed_version_id => version, :set_filter => 1) +
            " <small>(" + l(:label_total) + ": #{version.issues_count})</small></span>"
            end
            s << render_custom_field_progress_values(version,cf_values_to_display)
            if version.effective_date
              s << '<span class="initiative-due-date">' + l(:field_due_date) + ': ' + version.effective_date.to_s + '</span>'
              s << due_date_tag(version.effective_date)
            end
            s << '</div>'
            s << '<div class="version_sorted_score_list">' + render_version_score_card(version,project) + '</div>' if score_to_display
            s << progress_bar([version.closed_percent, version.completed_percent], :width => '30em', :legend => ('%0.0f%' % version.completed_percent))
          end
          s << "</div></li>"
        end
        s << '</ul>'
        s.html_safe
      end

      #renders project list sorted by project custom field value
      def render_project_cf_sorted_list(projects)
        options = {}
        options[:cf] = get_custom_fields_to_display("project")
        if Redmine::Plugin.registered_plugins.has_key?(:gttnl_bsc)
          if Setting["plugin_gttnl_bsc"] && Setting["plugin_gttnl_bsc"]["show_scorecard"] == "1" && Setting["plugin_gttnl_bsc"]["cf_for_score"].present?
            options[:score] = true
          end
        end
        s = '<ul class="projects root">'
        projects.each do |project|
          project.extend(Progressive::ProjectDecorator)
          s << '<li class="root"><div class="root">'
          s << link_to_project(project, {}, :class => "#{project.sorted_css_classes} #{User.current.member_of?(project) ? 'my-project' : nil}")
          if !progressive_setting?(:show_only_for_my_projects) || User.current.member_of?(project)
            if progressive_setting?(:show_project_menu)
              s << render_project_menu(project) + '<br />'.html_safe
            end
            if project.description.present? && progressive_setting?(:show_project_description)
              s << content_tag('div', textilizable(project.short_description, :project => project), :class => 'wiki description')
            else
              s << '<br/><br/>'
            end
            if progressive_setting?(:show_project_progress) && User.current.allowed_to?(:view_issues, project)
              s << render_project_progress_bars(project,options)
            end
          end
          s << '</div></li>'
        end
        s << '</ul>'
        return s.html_safe
      end

      #renders default hierarchical view of projects
      def render_nested_view(projects)
        options = {}
        options[:cf] = get_custom_fields_to_display("project")
        if Redmine::Plugin.registered_plugins.has_key?(:gttnl_bsc)
          if Setting["plugin_gttnl_bsc"] && Setting["plugin_gttnl_bsc"]["show_scorecard"] == "1" && Setting["plugin_gttnl_bsc"]["cf_for_score"].present?
            options[:score] = true
          end
        end
        render_project_nested_lists(projects) do |project|
          s = link_to_project(project, {}, :class => "#{project.css_classes} #{User.current.member_of?(project) ? 'my-project' : nil}")
          if !progressive_setting?(:show_only_for_my_projects) || User.current.member_of?(project)
            if progressive_setting?(:show_project_menu)
              s << render_project_menu(project) + '<br />'.html_safe
            end
            if project.description.present? && progressive_setting?(:show_project_description)
              s << content_tag('div', textilizable(project.short_description, :project => project), :class => 'wiki description')
            else
              s << '<br><br>'.html_safe
            end
            if progressive_setting?(:show_project_progress) && User.current.allowed_to?(:view_issues, project)
              s << render_project_progress_bars(project,options)
            end
          end
          s
        end
      end
      def render_custom_field_progress_values(element,custom_fields)
        value_string = ''
        custom_fields.each do |custom_field|
          val = element.custom_field_value(custom_field)
          val = val.join("").to_s if val.is_a?(Array)
          if val.present?
            value_string << "<span class='#{custom_field.name.split.join("_").downcase}'> #{custom_field.name}: #{val}</span>"
          end
        end
        value_string
      end
      # Returns project's and its versions' progress bars
      def render_project_progress_bars(project,options={})
        project.extend(Progressive::ProjectDecorator)
        s = ''
        if project.issues.open.any?
          s << '<div class="progressive-project-issues">' + l(:label_issue_plural) + ': ' +
            link_to(l(:label_x_open_issues_abbr, :count => project.issues.open.count), :controller => 'issues', :action => 'index', :project_id => project, :set_filter => 1) +
            " <small>(" + l(:label_total) + ": #{project.issues.count})</small> "
          if options[:cf]
           s << render_custom_field_progress_values(project,options[:cf])
          end
          s << due_date_tag(project.opened_due_date) if project.opened_due_date
          s << "</div>"
          s << render_project_score_card(project) if options[:score].present?
          s << progress_bar([project.issues_closed_percent, project.issues_completed_percent], :width => '30em', :legend => '%0.0f%' % project.issues_closed_percent)
        else
          if options[:cf]
            custom_field_values = render_custom_field_progress_values(project,options[:cf])
            s << "<br>" + custom_field_values if custom_field_values.present?
          end
          s << render_project_score_card(project) if options[:score].present?
        end

        if project.versions.open.any?
          s << '<div class="progressive-project-version">'
          project.versions.open.reverse_each do |version|
            next if version.completed?
            s << "<br/>" + "<div class='initiative-progress-bar'>" + l(:label_version) + " " + link_to_version(version) + ": " +
              link_to(l(:label_x_open_issues_abbr, :count => version.open_issues_count), :controller => 'issues', :action => 'index', :project_id => version.project, :status_id => 'o', :fixed_version_id => version, :set_filter => 1) +
              "<small> / " + link_to_if(version.closed_issues_count > 0, l(:label_x_closed_issues_abbr, :count => version.closed_issues_count), :controller => 'issues', :action => 'index', :project_id => version.project, :status_id => 'c', :fixed_version_id => version, :set_filter => 1) + "</small>" + ". "
            s << due_date_tag(version.effective_date) if version.effective_date
            
            if options[:score]
              s << render_version_score_card(version,project) 
            else
              s << "<br>"
            end
             s << progress_bar([version.closed_percent, version.completed_percent], :width => '30em', :legend => ('%0.0f%' % version.completed_percent))
             s << "</div>"
          end
          s << "</div>"
        end
        s.html_safe
      end

      def render_project_menu(project)
        links = []
        menu_items_for(:project_menu, project) do |node|
          links << render_menu_node(node, project)
        end
        links.empty? ? nil : content_tag('ul', links.join("\n").html_safe, :class => 'progressive-project-menu')
      end

      def render_project_score_card(project)
        s = ""
        score_hash = {}
        score_fields = project.all_issue_custom_fields.where(:id=>Setting["plugin_gttnl_bsc"]["cf_for_score"]) rescue []
        score_fields.each do |cf|
          score_hash[cf.id] = [cf.name,project.calculate_score(cf)]
        end
        if score_hash.present?
          s << "<div><span class='project_score_total'><b>" + l(:score_total) + ":" + score_hash.sum{|x,y| y[1]}.to_s + "</b></span>  "
          score_hash.each do |id,score|
            s  << "<span class='project_score_field_#{score[0].split.join("_").downcase.gsub("&","")}' style='padding-right: 4px'>" + "#{score[0]}:#{score[1].to_s}</span>"
          end
          s << "</div>"
        end
        s
      end

      def render_version_score_card(version,project)
        s = ""
        if version.respond_to?(:calculate_version_score)
          score_hash = {}
          score_fields = project.all_issue_custom_fields.where(:id=>Setting["plugin_gttnl_bsc"]["cf_for_score"]) rescue []
          score_fields.each do |cf|
            score_hash[cf.id] = [cf.name,version.calculate_version_score(cf)]
          end
          if score_hash.present?
            s << "<div><span class='project_version_score_total'><b>" + l(:score_total) + ":" + score_hash.sum{|x,y| y[1]}.to_s + "</b></span>"
            score_hash.each do |id,score|
              s  << "<span class='version_score_field_#{score[0].split.join("_").downcase.gsub("&","")}' style='padding-right: 4px'>" + "#{score[0]}:#{score[1].to_s}</span>"
            end
            s << "</div>"
          end
        end
        s
      end

      def due_date_tag(date)
        content_tag(:time, due_date_distance_in_words(date), :class => (date < Date.today ? 'progressive-overdue' : nil), :title => date)
      end

      def get_field_for_sort
        cf_for_sorting = nil
        sort_setting = progressive_setting(:sort_project_by)
        if sort_setting.present?
          return sort_setting if sort_setting == "sort_by_score"
          sort_setting = sort_setting.first if sort_setting.is_a?(Array)
          cf_for_sorting = CustomField.find(sort_setting) rescue nil
        end
        cf_for_sorting
      end

      alias_method_chain :render_project_hierarchy, :progress_bars
    end
  end
end

unless ProjectsHelper.include? Progressive::ProjectsHelperPatch
  ProjectsHelper.send(:include, Progressive::ProjectsHelperPatch)
end
