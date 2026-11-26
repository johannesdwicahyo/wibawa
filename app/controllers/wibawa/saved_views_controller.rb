module Wibawa
  class SavedViewsController < ApplicationController
    before_action :load_resource

    def create
      view = SavedView.new(resource_key: resource.key, owner: SavedView.owner_key(wibawa_current_user),
                           name: params[:name].to_s.strip,
                           query: SavedView.normalize(params[:query].to_s, default_per_page: SavedView.default_per_page(resource)))
      if view.save
        redirect_to index_url(view.query), notice: t("wibawa.flash.view_saved", name: view.name), status: :see_other
      else
        redirect_to index_url(view.query), alert: view.errors.full_messages.to_sentence, status: :see_other
      end
    end

    # Rename, share with everyone, or make it the page the index opens on.
    def update
      view = own_views.find(params[:id])
      if view.update(name: params[:name].to_s.strip, shared: params[:shared] == "1", default_view: params[:default_view] == "1")
        redirect_back_or_to index_url(view.query), notice: t("wibawa.flash.view_updated", name: view.name), status: :see_other
      else
        redirect_back_or_to index_url(view.query), alert: view.errors.full_messages.to_sentence, status: :see_other
      end
    end

    def destroy
      view = own_views.find(params[:id])
      view.destroy
      redirect_back_or_to index_url(nil), notice: t("wibawa.flash.view_deleted", name: view.name), status: :see_other
    end

    private

    attr_reader :resource

    def own_views = SavedView.owned_by(wibawa_current_user).where(resource_key: resource.key)

    def load_resource
      raise Wibawa::ResourceNotFound unless Wibawa.config.saved_views

      use_resource(params[:resource])
      ensure_action!(:index)
      wibawa_authorize!(:index, model)
    end

    def index_url(query)
      [ resources_path(resource: resource.key), query.presence ].compact.join("?")
    end
  end
end
