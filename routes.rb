resources :accounts_payables, :collection => { :context_menu => :post, :bulk_edit => :get, :bulk_update => :put, :auto_complete_for_vendor_invoice_number => :get, :timesheet => :get }
