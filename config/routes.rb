Wibawa::Engine.routes.draw do
  root to: "dashboard#show"

  # Model Context Protocol endpoint. Answers 404 until config.mcp_authenticate_with is set.
  match "mcp", to: "mcp#handle", via: %i[get post delete]

  # Only registered reports match, so a resource called "reports" keeps its own pages.
  get "reports/:report", to: "reports#show", as: :report,
                         constraints: ->(request) { Wibawa.registry.report(request.path_parameters[:report]) }

  scope ":resource" do
    get    "/",                       to: "resources#index",   as: :resources
    post   "/",                       to: "resources#create"
    get    "new",                     to: "resources#new",     as: :new_resource
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
