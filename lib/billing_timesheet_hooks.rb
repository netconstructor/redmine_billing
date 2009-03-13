class BillingTimesheetHooks < Redmine::Hook::ViewListener

  def plugin_timesheet_view_timesheets_context_menu(context={ })
    time_entries = context[:time_entries]
    
    o = ''
    if time_entries.size <= 0
      o << content_tag(:li,
                       context_menu_link(GLoc.l(:button_invoice),
                                         timesheet_accounts_payables_path(:time_entry_ids => time_entries.collect(&:id)),
                                         :style => "background-image: url(#{image_path('invoice.png', :plugin => 'billing_plugin')});",
                                         :disabled => true))
    else
      o << content_tag(:li,
                       context_menu_link(GLoc.l(:button_invoice),
                                         timesheet_accounts_payables_path(:time_entry_ids => time_entries.collect(&:id)),
                                         :style => "background-image: url(#{image_path('invoice.png', :plugin => 'billing_plugin')});",
                                         :rel => 'facebox'));
      
    end
    o << javascript_tag("jQuery('a[rel*=facebox]').facebox();");

    return o
  end
  
  def plugin_timesheet_view_timesheets_report_header_tags(context = { })
    return javascript_include_tag('jquery-1.2.6.min.js', :plugin => "billing_plugin") +
      javascript_include_tag('jquery.dimensions.min.js', :plugin => "billing_plugin") +
      javascript_include_tag('billing-timesheet.js', :plugin => "billing_plugin") +
      javascript_tag("jQuery.noConflict();") +
      stylesheet_link_tag("facebox.css", :plugin => "billing_plugin", :media => "screen") +
      javascript_include_tag('facebox', :plugin => "billing_plugin") +
      stylesheet_link_tag("billing-timesheet.css", :plugin => "billing_plugin", :media => "screen") +
      javascript_tag("var time_counter_url = '#{formatted_time_counter_accounts_payables_path(:format => 'json')}'")

  end
  
  def plugin_timesheet_view_timesheets_report_bottom(context = { })
    # TODO: Wish I could just render :partial in here
    inner_content = <<HTML
<a href='javascript:void(0)' id="minimize" onclick="jQuery('#counter-details').toggle(); return false;">-</a>
<h3>Selected Time Summary</h3>
<div id="counter-details">
<p id="total-time">
</p>
<p id="time-entry-count">
</p>
<hr />
<ul>
</ul>
</div>
HTML
    o = ''
    o << content_tag(:div, inner_content, :id => 'floating-counter', :style => 'display:none;')
    return o
  end

  # Adds a CSS class to the row on the Timesheet if a time_entry is missing a 
  # rate (based on it's cost).
  def plugin_timesheet_view_timesheets_time_entry_row_class(context = { })
    time_entry = context[:time_entry]
    if time_entry.cost && time_entry.cost <= 0 && time_entry.hours > 0
      return "missing-rate"
    else
      return ""
    end
  end

  # Cost and Invoice header columns
  def plugin_timesheet_views_timesheet_group_header(context = {})
    return "<th width='8%'>#{l(:billing_cost)}</th>" +
      "<th width='8%'>#{l(:billing_invoice_title)}</th>"
  end

  def plugin_timesheet_views_timesheet_time_entry(context = {})
    time_entry = context[:time_entry]
    o = ''
    o << cost_cell(time_entry)
    o << invoice_cell(time_entry)
    
    return o
  end

  def plugin_timesheet_views_timesheet_time_entry_sum(context = {})
    time_entries = context[:time_entries]
    o = ''
    costs = time_entries.collect {|time_entry| cost_item(time_entry)}.compact.sum
    o << td_cell(number_to_currency(costs))
    o << td_cell("&nbsp;") # Can't sum invoices
    
    return o
  end
  
  def plugin_timesheet_controller_report_pre_fetch_time_entries(context = { })
    if !context[:params][:timesheet].nil? && !context[:params][:timesheet][:vendor_invoice].nil?
      # Extend time an insane amount
      context[:timesheet].date_from = 100.years.ago.strftime("%Y-%m-%d")
      context[:timesheet].date_to = 100.years.from_now.strftime("%Y-%m-%d")
      # Add vendor_invoice
      context[:timesheet].vendor_invoice = context[:params][:timesheet][:vendor_invoice]
    end
  end
  
  def plugin_timesheet_model_timesheet_conditions(context = { })
    unless context[:timesheet].vendor_invoice.nil?
      vendor_invoice_id = context[:timesheet].vendor_invoice
      context[:conditions][0] << " AND vendor_invoice_id IN (?) "
      context[:conditions] << vendor_invoice_id
    end
  end

  # Returns the cost of a time entry, checking user permissions
  def cost_item(time_entry)
    if User.current.logged? && (User.current.allowed_to?(:view_rate, time_entry.project) || User.current.admin?)
      return time_entry.cost
    else
      return nil
    end
  end

  # Returns a td cell of the time_entry's cost
  def cost_cell(time_entry)
    cost = cost_item(time_entry)
    if cost
      return td_cell(number_to_currency(cost))
    else
      return td_cell('&nbsp;')
    end
  end

  # Returns a td cell of the time_entry's invoice
  def invoice_cell(time_entry)
    if User.current.logged? && User.current.allowed_to?(:use_accounts_payable, nil, :global => true) && time_entry.vendor_invoice
      invoice = link_to(h(time_entry.vendor_invoice.number),
                        accounts_payable_path(time_entry.vendor_invoice))
    else
      invoice = '&nbsp;'
    end
    return td_cell(invoice)
  end

  def td_cell(html)
    return content_tag(:td, html, :align => 'right')
  end
end
