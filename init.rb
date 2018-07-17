unless File.basename(File.dirname(__FILE__)) == 'gttnl_strategy_progress'
  raise "GTTNL Strategy Progress plugin directory should be 'gttnl_strategy_progress' instead of '#{File.basename(File.dirname(__FILE__))}'"
end

Redmine::Plugin.register :gttnl_strategy_progress do
  name 'GTTNL Strategy Progress plugin'
  author  'Dmitry Babenko & Kumar Abhinav'
  description 'GTTNL implementation of Strategy List with menus and progress bars.'
  version '3.0.1'
  url 'http://stgeneral.github.io/redmine-progressive-projects-list/'
  author_url 'https://github.com/stgeneral'
  requires_redmine :version_or_higher => '3.0'

  settings :default => {
    'show_project_description'  => false,
    'show_project_progress'     => true,
    'show_project_menu'         => false,
    'show_only_for_my_projects' => false,
    'show_recent_projects'      => true,
    'show_custom_date_fields'   => false,
    'show_strategy_initiative_scorecard' => false,
    'show_project_progress_overview' => '',
    'project_sort_order' => "asc" 
  }, :partial => 'settings/progressive_projects_list'
end

require 'progressive/application_helper_patch'
require 'progressive/projects_helper_patch'
require 'progressive/projects_list_view_listener'
require 'progressive/recent_projects_view_listener'
require 'progressive/project_patch_gttnl_strategy_progress'
