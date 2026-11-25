# In a file, like a real app, so Active Storage can add its own routes next to these.
Rails.application.routes.draw do
  mount Wibawa::Engine, at: "/admin"
  get "/favicon.ico", to: ->(_env) { [ 204, {}, [] ] } # browsers ask for one
end
