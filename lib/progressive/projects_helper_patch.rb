module Progressive::ProjectsHelperPatch
  def self.included(base) # :nodoc:
    base.class_eval do

      def render_project_hierarchy_with_progress_bars(projects)
        cf_for_sorting = get_custom_field_for_sort
        if projects.present? && cf_for_sorting.present?
          case cf_for_sorting.class.to_s
          when "ProjectCustomField"
            sort_by_project_custom_field(projects,cf_for_sorting)
          when "VersionCustomField"
            sort_by_version_custom_field(projects,cf_for_sorting)
          else
            render_nested_view(projects)
          end
        else
        render_nested_view(projects)
      end
      end

      def sort_by_project_custom_field(projects,cf_for_sorting)
        sort_criteria = Setting.plugin_progressive_projects_list["project_sort_order"]
        sort_criteria = "asc" if sort_criteria.nil?
        default_project_sort = Setting.plugin_progressive_projects_list["default_project_sort"]
        default_project_sort = "name" if default_project_sort.nil?
        project_ids = projects.collect(&:id)
        sorted_projects = Project.joins(:custom_values).where(projects:{id: project_ids},custom_values:{custom_field_id: cf_for_sorting.id}).where("custom_values.value <> ''").order("STR_TO_DATE(custom_values.value, '%Y-%m-%d') #{sort_criteria}").uniq
        project_without_values = projects - sorted_projects.to_a
        project_without_values.sort_by!(&default_project_sort.to_sym)
        render_project_cf_sorted_list(sorted_projects+project_without_values,cf_for_sorting)
      end

      def sort_by_version_custom_field(projects,cf_for_sorting)
        sort_criteria = Setting.plugin_progressive_projects_list["project_sort_order"]
        sort_criteria = "asc" if sort_criteria.nil?
        project_ids = projects.collect(&:id)
        sorted_versions =  Version.visible.joins(:custom_values).where(versions:{project_id: project_ids},custom_values:{custom_field_id: cf_for_sorting.id}).where("custom_values.value <> ''").order("STR_TO_DATE(custom_values.value, '%Y-%m-%d') #{sort_criteria}").uniq
        render_version_cf_sorted_list(sorted_versions,cf_for_sorting)
      end

      def render_version_cf_sorted_list(versions,cf_for_sorting)
        s = '<ul class="projects root">'
        versions.each do |version|
          project = version.project
          project.extend(Progressive::ProjectDecorator)
          s << '<li class="root"><div class="root version-text">'
          s << link_to_version(version) + ' : '.html_safe
          s << link_to_if(version.open_issues_count > 0,
                     l(:label_x_open_issues_abbr, :count => version.open_issues_count),
                     generate_version_filtered_issues_path(version, :status_id => 'o'))
          s << " / ".html_safe
          s << link_to_if(version.closed_issues_count > 0,
                      l(:label_x_closed_issues_abbr, :count => version.closed_issues_count),
                      generate_version_filtered_issues_path(version, :status_id => 'c'))
          if version.effective_date && version.effective_date < Date.today
              s << '  <span class="red-text">'.html_safe
              s << due_date_distance_in_words(version.effective_date)
              s << '</span>'.html_safe
          end
          s << '<br/><span class="version-project"'
          s << link_to_project(project)
          val = version.custom_field_value(cf_for_sorting)
          val = val.join("").to_s if val.is_a?(Array)
          if val.present?
            s << ", #{cf_for_sorting.name}: #{val}"
            else
            s << ", <span class='required'>*</span>"
          end
          s << '</span>'
          s << '<div class="progressive-project-version margin-adjust">'
          s << "<br>" +
              progress_bar([version.closed_percent, version.completed_percent], :width => '30em', :legend => ('%0.0f%' % version.completed_percent))
          s << "</div>"
          s << '</div></li>'
        end
        s << '</ul>'
        s.html_safe
      end
    def generate_version_filtered_issues_path(version, options = {})
    options = {:fixed_version_id => version, :set_filter => 1}.merge(options)
    project = case version.sharing
      when 'hierarchy', 'tree'
        if version.project && version.project.root.visible?
          version.project.root
        else
          version.project
        end
      when 'system'
        nil
      else
        version.project
    end

    if project
      project_issues_path(project, options)
    else
      issues_path(options)
    end
  end
      def render_project_cf_sorted_list(projects,cf_for_sorting)
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
              end
              if progressive_setting?(:show_project_progress) && User.current.allowed_to?(:view_issues, project)
                s << render_project_progress_bars(project,{cf: cf_for_sorting})
              end
            end
              s << '</div></li>'
          end
          s << '</ul>'
          return s.html_safe
      end

      def render_nested_view(projects)
        render_project_nested_lists(projects) do |project|
        s = link_to_project(project, {}, :class => "#{project.css_classes} #{User.current.member_of?(project) ? 'my-project' : nil}")
            if !progressive_setting?(:show_only_for_my_projects) || User.current.member_of?(project)
              if progressive_setting?(:show_project_menu)
                s << render_project_menu(project) + '<br />'.html_safe
              end
              if project.description.present? && progressive_setting?(:show_project_description)
                s << content_tag('div', textilizable(project.short_description, :project => project), :class => 'wiki description')
              end
              if progressive_setting?(:show_project_progress) && User.current.allowed_to?(:view_issues, project)
                s << render_project_progress_bars(project)
              end
            end
            s
          end
      end

      # Returns project's and its versions' progress bars
      def render_project_progress_bars(project,options={})
        project.extend(Progressive::ProjectDecorator)
        s = ''
        if project.issues.open.any?
          s << '<div class="progressive-project-issues">' + l(:label_issue_plural) + ': ' +
            link_to(l(:label_x_open_issues_abbr, :count => project.issues.open.count), :controller => 'issues', :action => 'index', :project_id => project, :set_filter => 1) +
            " <small>(" + l(:label_total) + ": #{project.issues.count})</small> "
          s << due_date_tag(project.opened_due_date) if project.opened_due_date
          if options[:cf]
            
            val = project.custom_field_value(options[:cf])
            val = val.join("").to_s if val.is_a?(Array)
            if val.present?
              s << ", #{options[:cf].name}: #{val}"
            else
              s << ", <span class='required'>*</span>"
            end
           # s << val.present? ?  : 
          end
          s << "</div>"
          s << progress_bar([project.issues_closed_percent, project.issues_completed_percent], :width => '30em', :legend => '%0.0f%' % project.issues_closed_percent)
        end

        if project.versions.open.any?
          s << '<div class="progressive-project-version">'
          project.versions.open.reverse_each do |version|
            next if version.completed?
            s << l(:label_version) + " " + link_to_version(version) + ": " +
              link_to(l(:label_x_open_issues_abbr, :count => version.open_issues_count), :controller => 'issues', :action => 'index', :project_id => version.project, :status_id => 'o', :fixed_version_id => version, :set_filter => 1) +
              "<small> / " + link_to_if(version.closed_issues_count > 0, l(:label_x_closed_issues_abbr, :count => version.closed_issues_count), :controller => 'issues', :action => 'index', :project_id => version.project, :status_id => 'c', :fixed_version_id => version, :set_filter => 1) + "</small>" + ". "
            s << due_date_tag(version.effective_date) if version.effective_date
            s << "<br>" +
              progress_bar([version.closed_percent, version.completed_percent], :width => '30em', :legend => ('%0.0f%' % version.completed_percent))
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

      def due_date_tag(date)
        content_tag(:time, due_date_distance_in_words(date), :class => (date < Date.today ? 'progressive-overdue' : nil), :title => date)
      end

      def get_custom_field_for_sort
        cf_for_sorting = nil
        sort_setting = progressive_setting(:sort_project_by)
        if sort_setting.present?
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
