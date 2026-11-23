$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "minitest/autorun"
require "wibawa"
require "wibawa/paginator"
require "wibawa/csv_exporter"
require "wibawa/authorization"

# A stand-in for an ActiveRecord model: enough reflection for the DSL.
class FakeModel
  Reflection = Struct.new(:name, :macro, :foreign_key, :klass) do
    def polymorphic? = false
  end

  def self.name = "Order"
  def self.reflections = @reflections ||= {}
  def self.reflect_on_association(name) = reflections[name.to_sym]
  def self.reflect_on_attachment(_name) = nil
  def self.column_names = %w[id number status total customer_id notes created_at updated_at]
end

class FakeLineItem
  def self.name = "LineItem"
  def self.reflect_on_association(_) = nil
  def self.reflect_on_attachment(_) = nil
end

class FakeCustomer
  def self.name = "Customer"
end

FakeModel.reflections[:customer] = FakeModel::Reflection.new(:customer, :belongs_to, "customer_id", FakeCustomer)
FakeModel.reflections[:line_items] = FakeModel::Reflection.new(:line_items, :has_many, "order_id", FakeLineItem)
FakeModel.reflections[:tags] = FakeModel::Reflection.new(:tags, :has_many, "order_id", FakeLineItem)
