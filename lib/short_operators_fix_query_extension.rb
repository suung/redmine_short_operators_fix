
#
# This module fixes the fact, that querying via the short operator any custom fields starting with c or o have been miss-filtered
#
# This module also shows the problems with Query, because you see, where we had to patch around just to change an operator --suung
#
module ShortOperatorsFix

  #
  
  def self.included(base)
    
    base.send(:include, InstanceMethods)

    base.class_eval do
      @@operators = { "="   => :label_equals,
        "!"   => :label_not_equals,
        "o="   => :label_open_issues,
        "c="   => :label_closed_issues,
        "!*"  => :label_none,
        "*"   => :label_all,
        ">="  => :label_greater_or_equal,
        "<="  => :label_less_or_equal,
        "<t+" => :label_in_less_than,
        ">t+" => :label_in_more_than,
        "t+"  => :label_in,
        "t"   => :label_today,
        "w"   => :label_this_week,
        ">t-" => :label_less_than_ago,
        "<t-" => :label_more_than_ago,
        "t-"  => :label_ago,
        "~"   => :label_contains,
        "!~"  => :label_not_contains,
      }

      cattr_reader :operators

      @@operators_by_filter_type = { :list => [ "=", "!" ],
        :list_status => [ "o=", "=", "!", "c=", "*" ],
        :list_optional => [ "=", "!", "!*", "*" ],
        :list_multiple => ["~", "!~","~*"],
        :list_subprojects => [ "*", "!*", "=" ],
        :date => [ "<t+", ">t+", "t+", "t", "w", ">t-", "<t-", "t-" ],
        :date_past => [ ">t-", "<t-", "t-", "t", "w" ],
        :string => [ "=", "~", "!", "!~","~*"],
        :text => [  "~", "!~","~*","!~*"],
        :integer => [ "=", ">=", "<=", "!*", "*" ] }

      cattr_reader :operators_by_filter_type
      alias_method_chain :after_initialize, :custom_fields_api
      alias_method_chain :add_short_filter, :custom_fields_api
      alias_method_chain :validate, :custom_fields_api
      alias_method_chain :sql_for_field, :custom_fields_api
    end
    
  end 
  
  module InstanceMethods

    
    def after_initialize_with_custom_fields_api
      self.filters ? self.filters["status_id"][:operator] = "o=" : self.filters = { 'status_id' => {:operator => "o=", :values => [""]} }
      # Store the fact that project is nil (used in #editable_by?)
      @is_for_all = project.nil?
    end
    
    # Helper method to generate the WHERE sql for a +field+, +operator+ and a +value+
    def sql_for_field_with_custom_fields_api(field, operator, value, db_table, db_field, is_custom_filter=false)
      sql = ''
      case operator
      when "="
        if value.present?
          sql = "#{db_table}.#{db_field} IN (" + value.collect{|val| "'#{connection.quote_string(val)}'"}.join(",") + ")"
        else
          # empty set of allowed values produces no result
          sql = "0=1"
        end
      when "!"
        if value.present?
          sql = "(#{db_table}.#{db_field} IS NULL OR #{db_table}.#{db_field} NOT IN (" + value.collect{|val| "'#{connection.quote_string(val)}'"}.join(",") + "))"
        else
          # empty set of forbidden values allows all results
          sql = "1=1"
        end
      when "!*"
        sql = "#{db_table}.#{db_field} IS NULL"
        sql << " OR #{db_table}.#{db_field} = ''" if is_custom_filter
      when "*"
        sql = "#{db_table}.#{db_field} IS NOT NULL"
        sql << " AND #{db_table}.#{db_field} <> ''" if is_custom_filter
      when ">="
        sql = "#{db_table}.#{db_field} >= #{value.first.to_i}"
      when "<="
        sql = "#{db_table}.#{db_field} <= #{value.first.to_i}"
      when "o="
        sql = "#{IssueStatus.table_name}.is_closed=#{connection.quoted_false}" if field == "status_id"
      when "c="
        sql = "#{IssueStatus.table_name}.is_closed=#{connection.quoted_true}" if field == "status_id"
      when ">t-"
        sql = date_range_clause(db_table, db_field, - value.first.to_i, 0)
      when "<t-"
        sql = date_range_clause(db_table, db_field, nil, - value.first.to_i)
      when "t-"
        sql = date_range_clause(db_table, db_field, - value.first.to_i, - value.first.to_i)
      when ">t+"
        sql = date_range_clause(db_table, db_field, value.first.to_i, nil)
      when "<t+"
        sql = date_range_clause(db_table, db_field, 0, value.first.to_i)
      when "t+"
        sql = date_range_clause(db_table, db_field, value.first.to_i, value.first.to_i)
      when "t"
        sql = date_range_clause(db_table, db_field, 0, 0)
      when "w"
        from = l(:general_first_day_of_week) == '7' ?
        # week starts on sunday
        ((Date.today.cwday == 7) ? Time.now.at_beginning_of_day : Time.now.at_beginning_of_week - 1.day) :
          # week starts on monday (Rails default)
          Time.now.at_beginning_of_week
        sql = "#{db_table}.#{db_field} BETWEEN '%s' AND '%s'" % [connection.quoted_date(from), connection.quoted_date(from + 7.days)]
      when "~"
        sql = "LOWER(#{db_table}.#{db_field}) LIKE '%#{connection.quote_string(value.first.to_s.downcase)}%'"
      when "!~"
        sql = "LOWER(#{db_table}.#{db_field}) NOT LIKE '%#{connection.quote_string(value.first.to_s.downcase)}%'"
      end

      return sql
    end
    
    
    def validate_with_custom_fields_api
      filters.each_key do |field|
        errors.add label_for(field), :blank unless
          # filter requires one or more values
          (values_for(field) and !values_for(field).first.blank?) or
          # filter doesn't require any value
          ["o=", "c=", "!*", "*", "t", "w"].include? operator_for(field)
      end if filters
    end

    
    def add_short_filter_with_custom_fields_api(field, expression)
      return unless expression
      parms = expression.scan(/^(=|o=|c=|!\*|!|\*)?(.*)$/).first
      add_filter field, (parms[0] || "="), [parms[1] || ""]
    end
    
    
    
  end
  
  
end
