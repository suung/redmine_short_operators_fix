# Include hook code here

require 'redmine'
require 'dispatcher'


Dispatcher.to_prepare :short_operators_fix do
  require_dependency 'query'
  Query.send(:include, ShortOperatorsFixQueryExtension) unless Query.included_modules.include?(ShortOperatorsFixQueryExtension)
end


Redmine::Plugin.register :custom_fields_api do
  name 'Redmine Short Operators Fix'
  author 'suung | devolute'
  description 'Fixes some inacceptable issues with the search api'
  version '0.0.1'
  author_url 'http://www.devolute.org'

  requires_redmine :version_or_higher => '0.8.0'

  
end
