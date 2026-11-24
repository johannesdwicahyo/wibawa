Wibawa::Engine.routes.draw do
  root to: "dashboard#show"

  # Model Context Protocol endpoint. Answers 404 until config.mcp_authenticate_with is set.
  match "mcp", to: "mcp#handle", via: %i[get post delete]

  get "-/search", to: "search#index", as: :search

  # Only registered pages match, so a resource called "pages" keeps its own.
  constraints ->(request) { Wibawa.registry.page(request.path_parameters[:page]) } do
    get  "pages/:page",              to: "pages#show", as: :page
    post "pages/:page/:page_action", to: "pages#run",  as: :page_action
  end

  # Only registered reports match, so a resource called "reports" keeps its own pages.
  get "reports/:report", to: "reports#show", as: :report,
                         constraints: ->(request) { Wibawa.registry.report(request.path_parameters[:report]) }

  scope ":resource" do
    get    "/",                       to: "resources#index",   as: :resources
    post   "/",                       to: "resources#create"
    get    "new",                     to: "resources#new",     as: :new_resource
    get    "options/:target",         to: "resources#options", as: :options_resource
    post   "views",                   to: "saved_views#create",  as: :saved_views
    delete "views/:id",               to: "saved_views#destroy", as: :saved_view
    post   "batch",                   to: "resources#batch",   as: :batch_resources
    get    ":id",                     to: "resources#show",    as: :resource
    patch  ":id",                     to: "resources#update"
    put    ":id",                     to: "resources#update"
    delete ":id",                     to: "resources#destroy"
    get    ":id/edit",                to: "resources#edit",    as: :edit_resource
    match  ":id/actions/:member_action", to: "resources#member", as: :member_action_resource,
                                         via: %i[get post patch put delete]
  end
end
