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
        redirect_to after_save_path, notice: t("wibawa.flash.updated", resource: resource.singular_label), status: :see_other
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      ensure_action!(:destroy)
      wibawa_authorize!(:destroy, record)

      if record.destroy
        redirect_to resources_path(resource: resource.key), notice: t("wibawa.flash.destroyed", resource: resource.singular_label), status: :see_other
      else
        redirect_back_or_to resource_path(resource: resource.key, id: record),
                            alert: record.errors.full_messages.to_sentence.presence || t("wibawa.flash.destroy_failed"),
                            status: :see_other
      end
    end

    def batch
      action = resource.find_batch_action(params[:batch_action]) || raise(Wibawa::ResourceNotFound)
      wibawa_authorize!(:"batch_#{action.name}", model)

      ids = Array(params[:ids]).compact_blank
      return redirect_back_or_to(resources_path(resource: resource.key), alert: t("wibawa.flash.nothing_selected"), status: :see_other) if ids.empty?

      records = authorized_collection.where(model.primary_key => ids)
      result = action.block ? instance_exec(records, &action.block) : batch_destroy(records)
      return if performed?

      message = result.is_a?(String) ? result : t("wibawa.flash.batch_done", action: action.label, count: ids.size)
      redirect_back_or_to resources_path(resource: resource.key), notice: message, status: :see_other
    end

    def member
      action = resource.find_member_action(params[:member_action]) || raise(Wibawa::ResourceNotFound)
      raise Wibawa::ResourceNotFound unless request.request_method_symbol == action.http_method

      wibawa_authorize!(action.name, record)
      result = instance_exec(record, &action.block)
      return if performed?

      message = result.is_a?(String) ? result : t("wibawa.flash.action_done", action: action.label)
      redirect_to resource_path(resource: resource.key, id: record), notice: message, status: :see_other
    end

    private

    def load_resource
      @resource = Wibawa.registry.fetch(params[:resource])
      resource.controller_blocks.each { |block| singleton_class.class_eval(&block) }
    end

    def load_record
      @record = find_record
    end

    def model = resource.model

    # ---- Hooks: override per resource with `controller do ... end` ---------

    # Base relation for index, batch and record lookup.
    def scoped_collection
      model.all
    end

    def authorized_collection
      wibawa_authorizer.scope(scoped_collection)
    end

    def find_record
      authorized_collection.find(params[:id])
    end

    def build_record
      scoped_collection.new
    end

    def record_params
      params.fetch(:record, {}).permit(*resource.permitted_attributes)
    end

    def after_save_path
      if resource.action?(:show)
        resource_path(resource: resource.key, id: record)
      else
        resources_path(resource: resource.key)
      end
    end

    def per_page
      requested = params[:per_page].to_i
      default = resource.index_options[:per_page] || Wibawa.config.per_page
      requested.positive? ? [requested, Wibawa.config.max_per_page].min : default
    end

    # ---- Helpers -----------------------------------------------------------

    def ensure_action!(action)
      raise Wibawa::ResourceNotFound unless resource.action?(action)
    end

    def batch_destroy(records)
      destroyed = 0
      records.find_each { |r| destroyed += 1 if r.destroy }
      t("wibawa.flash.batch_destroyed", count: destroyed)
    end

    def stream_csv(relation)
      exporter = Wibawa::CsvExporter.new(resource, relation, wibawa_presenter)
      response.headers["Content-Type"] = "text/csv; charset=utf-8"
      response.headers["Content-Disposition"] =
        ActionDispatch::Http::ContentDisposition.format(disposition: "attachment", filename: exporter.filename)
      response.headers["Cache-Control"] = "no-cache"
      response.headers["X-Accel-Buffering"] = "no"
      response.headers["Last-Modified"] = Time.now.httpdate # stops Rack::ETag from buffering the stream
      response.headers.delete("Content-Length")
      self.response_body = exporter.lines
    end
  end
end
