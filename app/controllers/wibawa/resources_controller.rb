module Wibawa
  # One controller serves every registered resource. Per-resource overrides
  # come from `controller do ... end` blocks in the resource definition, which
  # are mixed into the controller instance for that request.
  class ResourcesController < ApplicationController
    before_action :load_resource
    before_action :load_record, only: %i[show edit update destroy member]

    helper_method :resource, :record, :query, :page

    attr_reader :resource, :record, :query, :page

    def index
      ensure_action!(:index)
      if request.format.csv?
        wibawa_authorize!(:export, model)
        @query = Wibawa::Query.new(resource, authorized_collection, params)
        stream_csv(@query.relation)
      else
        wibawa_authorize!(:index, model)
        if (url = default_view_url)
          flash.keep # a notice from the page that sent us here
          return redirect_to(url)
        end
        @query = Wibawa::Query.new(resource, authorized_collection, params)
        options = resource.index_options
        @page = Wibawa::Paginator.new(@query.relation, page: params[:page], per_page: per_page, count: options[:count])
      end
    end

    def show
      ensure_action!(:show)
      wibawa_authorize!(:show, record)
    end

    def new
      ensure_action!(:new)
      @record = build_record
      wibawa_authorize!(:new, record)
    end

    def create
      ensure_action!(:create)
      @record = build_record
      record.assign_attributes(record_params)
      wibawa_authorize!(:create, record)

      if record.save
        wibawa_audit(:create, record, record.saved_changes)
        redirect_to after_save_path, notice: t("wibawa.flash.created", resource: resource.singular_label), status: :see_other
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      ensure_action!(:edit)
      wibawa_authorize!(:edit, record)
    end

    def update
      ensure_action!(:update)
      wibawa_authorize!(:update, record)
      record.assign_attributes(record_params)

      if record.save
        wibawa_audit(:update, record, record.saved_changes)
        redirect_to after_save_path, notice: t("wibawa.flash.updated", resource: resource.singular_label), status: :see_other
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      ensure_action!(:destroy)
      wibawa_authorize!(:destroy, record)

      if record.destroy
        wibawa_audit(:destroy, record)
        redirect_to resources_path(resource: resource.key), notice: t("wibawa.flash.destroyed", resource: resource.singular_label), status: :see_other
      else
        redirect_back_or_to resource_path(resource: resource.key, id: record),
                            alert: record.errors.full_messages.to_sentence.presence || t("wibawa.flash.destroy_failed"),
                            status: :see_other
      end
    end

    # GET: the upload form (or, as .csv, an empty template). POST: run the import,
    # or with dry_run only check the file and show what it would do.
    def import
      raise Wibawa::ResourceNotFound unless resource.importable?

      wibawa_authorize!(:import, model)
      @importer = Wibawa::CsvImporter.new(resource, find_in: authorized_collection, build: -> { build_record },
                                                    authorize: ->(action, record) { wibawa_authorized?(action, record) })
      return send_data(CSV.generate_line(@importer.headers), filename: "#{resource.key}-template.csv", type: "text/csv; charset=utf-8") if request.format.csv?
      @recent = Wibawa::Import.visible_to(wibawa_current_user).where(resource_key: resource.key).order(id: :desc).limit(5) if Wibawa.config.background_import
      return unless request.post?

      text = params[:file].respond_to?(:read) ? params[:file].read : ""
      # A rough count: a line break inside a quoted cell counts too, which only sends a file to the job sooner.
      if text.count("\n") > Wibawa::CsvImporter::MAX_ROWS && Wibawa::Import.possible?(resource, wibawa_current_user)
        import = Wibawa::Import.start!(resource, wibawa_current_user, text, filename: params[:file].original_filename, dry_run: params[:dry_run].present?)
        return redirect_to(import_status_resource_path(resource: resource.key, id: import), status: :see_other)
      end

      @result = @importer.call(text, dry_run: params[:dry_run].present?)
      return render(:import, status: :unprocessable_entity) unless @result.ok?
      return render(:import) if @result.dry_run

      wibawa_audit(:import, nil, { created: @result.created, updated: @result.updated })
      redirect_to resources_path(resource: resource.key), status: :see_other,
                  notice: t("wibawa.flash.imported", created: @result.created, updated: @result.updated)
    end

    # Where a background import is watched: waiting, then what it did.
    def import_status
      raise Wibawa::ResourceNotFound unless resource.importable? && Wibawa.config.background_import

      wibawa_authorize!(:import, model)
      @import = Wibawa::Import.visible_to(wibawa_current_user).where(resource_key: resource.key).find(params[:id])
    end

    # Choices for a searchable select, as <li> options. `target` must be a
    # model this resource's form or filters point at.
    def options
      target = resource.option_classes[params[:target]] || raise(Wibawa::ResourceNotFound)
      raise Wibawa::NotAuthorized unless %i[index create update].any? { |action| wibawa_authorized?(action, model) }

      @options = Wibawa::ComboboxComponent.search(target, wibawa_authorizer.scope(target.all), params[:q])
      render layout: false
    end

    def batch
      action = resource.find_batch_action(params[:batch_action]) || raise(Wibawa::ResourceNotFound)
      wibawa_authorize!(:"batch_#{action.name}", model)

      ids = Array(params[:ids]).compact_blank
      return redirect_back_or_to(resources_path(resource: resource.key), alert: t("wibawa.flash.nothing_selected"), status: :see_other) if ids.empty?

      action, result, = run_batch_action(action.name, ids)
      return if performed?

      message = result.is_a?(String) ? result : t("wibawa.flash.batch_done", action: action.label, count: ids.size)
      redirect_back_or_to resources_path(resource: resource.key), notice: message, status: :see_other
    end

    def member
      action = resource.find_member_action(params[:member_action]) || raise(Wibawa::ResourceNotFound)
      raise Wibawa::ResourceNotFound unless request.request_method_symbol == action.http_method

      wibawa_authorize!(action.name, record)
      result = instance_exec(record, &action.block)
      wibawa_audit(action.name, record)
      return if performed?

      message = result.is_a?(String) ? result : t("wibawa.flash.action_done", action: action.label)
      redirect_to resource_path(resource: resource.key, id: record), notice: message, status: :see_other
    end

    private

    # A bare index URL opens on the user's default saved view.
    # ponytail: "bare" must still be reachable, so a link from the index page
    # itself (clear filters, the All scope) is left alone; that is read from the
    # Referer header. Without the header the default opens again, which is safe.
    def default_view_url
      return unless Wibawa.config.saved_views && request.format.html? && request.query_parameters.empty?
      return if request.referer && URI(request.referer).path == request.path

      view = Wibawa::SavedView.default_for(resource.key, wibawa_current_user)
      "#{request.path}?#{view.query}" if view&.query.present?
    rescue URI::InvalidURIError
      nil
    end

    def load_resource
      use_resource(params[:resource])
    end

    def load_record
      @record = find_record
    end

    def after_save_path
      if resource.action?(:show)
        resource_path(resource: resource.key, id: record)
      else
        resources_path(resource: resource.key)
      end
    end

    # ---- Helpers -----------------------------------------------------------

    def stream_csv(relation)
      exporter = Wibawa::CsvExporter.new(resource, relation, wibawa_presenter)
      stream_csv_lines(exporter.filename, exporter.lines)
    end
  end
end
