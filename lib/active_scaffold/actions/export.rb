module ActiveScaffold::Actions
  module Export
    def self.included(base)
      base.before_filter :export_authorized?, :only => [:export]
      base.before_filter :init_session_var

      as_export_plugin_path = File.join(Rails.root, 'vendor', 'plugins', ActiveScaffold::Config::Export.plugin_directory, 'frontends', 'default' , 'views')
      
      base.add_active_scaffold_path as_export_plugin_path
    end

    def init_session_var
      session[:search] = params[:search] if !params[:search].nil? || params[:commit] == as_('Search')
    end

    # display the customization form or skip directly to export
    def show_export
      export_config = active_scaffold_config.export
      respond_to do |wants|
        wants.html do
          if successful?
            render(:partial => 'show_export', :layout => true)
          else
            return_to_main
          end
        end
        wants.js do
          render(:partial => 'show_export', :layout => false)
        end
      end
    end

    # if invoked directly, will use default configuration
    def export
      export_config = active_scaffold_config.export
      if params[:export_columns].nil?
        export_columns = {}
        export_config.columns.each { |col|
          export_columns[col.name.to_sym] = 1
        }
        options = {
          :export_columns => export_columns,
          :full_download => export_config.default_full_download.to_s,
          :delimiter => export_config.default_delimiter,
          :skip_header => export_config.default_skip_header.to_s
        }
        params.merge!(options)
      end

      find_items_for_export

      if params[:format] == "CSV"
        @export_library = :fastercsv
        response.headers['Content-Disposition'] = "attachment; filename=#{export_file_name(:csv)}"
        render :partial => 'export', :layout => false, :content_type => Mime::CSV, :status => response_status 
      elsif params[:format] == "RawXML"
        render :xml => @records.to_xml
      elsif params[:format] == "EnhancedXML"
        render :partial => 'listxml'
      elsif params[:format] == "EnhancedXMLToFile"
        @stylesheet_file = export_file_name(:xsl)
        headers["Content-Type"] = "text/xml"
        headers["Content-Disposition"] = "attachment; filename=\"#{export_file_name(:xml)}\""
        render :partial => 'listxml'
      elsif params[:format] == "Stylesheet"
        @bgcolor = bgcolor
        headers["Content-Type"] = "text/xml"
        headers["Content-Disposition"] = "attachment; filename=\"#{export_file_name(:xsl)}\""
        render :partial => 'stylesheet', :layout => false
      elsif params[:format] == "Excel"
        @export_library = :surpass
        headers["Content-Disposition"] = "attachment; filename=\"#{export_file_name(:xls)}\""
        render :partial => 'export', :layout => false, :content_type => Mime::XLS, :status => response_status 
      end
    end

    protected

    # The actual algorithm to do the export
    def find_items_for_export
      export_config = active_scaffold_config.export
      export_columns = export_config.columns.reject { |col| params[:export_columns][col.name.to_sym].nil? }

      includes_for_export_columns = export_columns.collect{ |col| col.includes }.flatten.uniq.compact
      self.active_scaffold_includes.concat includes_for_export_columns

      find_options = { :sorting => active_scaffold_config.list.user.sorting }
      params[:search] = session[:search]
      do_search rescue nil
      params[:segment_id] = session[:segment_id]
      do_segment_search rescue nil
      unless params[:full_download] == 'true'
        find_options.merge!({
          :per_page => active_scaffold_config.list.user.per_page,
          :page => active_scaffold_config.list.user.page
        })
      end

      @export_config = export_config
      @export_columns = export_columns
      @records = find_page(find_options).items
    end

    # The default name of the downloaded file.
    # You may override the method to specify your own file name generation.
    def export_file_name(extension)
      return "#{export_controller}.#{extension.to_s}" if extension == :xsl
      "#{export_file}.#{extension.to_s}"
    end
    
    def export_controller
      "#{self.controller_name}"
    end
    
    def export_file
      "#{export_controller}_#{Time.now.strftime('%Y-%m-%d')}"
    end
    
    def bgcolor
      "#9acd32"
    end

    # The default security delegates to ActiveRecordPermissions.
    # You may override the method to customize.
    def export_authorized?
      authorized_for?(:action => :read)
    end
  end
end
