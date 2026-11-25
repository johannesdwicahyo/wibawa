# Nothing but declarations: its admin pages are inferred, uploads and rich text included.
class Product < ApplicationRecord
  has_one_attached :photo
  has_many_attached :documents
  has_rich_text :description
end
