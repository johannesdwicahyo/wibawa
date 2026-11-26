require "spec_helper"
require "tmpdir"
require "generators/wibawa/resource/resource_generator"

RSpec.describe Wibawa::Generators::ResourceGenerator do
  before do
    ActiveRecord::Schema.define do
      create_table :api_keys, force: true do |t|
        t.string :name
        t.string :digest
        t.string :token
        t.string :otp_secret
        t.string :password_digest
        t.decimal :monthly_fee, precision: 12, scale: 2
        t.decimal :tax_rate
        t.integer :total
        t.timestamps
      end
    end
    stub_const("ApiKey", Class.new(ActiveRecord::Base) { self.table_name = "api_keys" })
  end
  after { ActiveRecord::Schema.define { drop_table :api_keys } }

  it "leaves secret columns out, says so, and shows decimal money columns as money" do
    Dir.mktmpdir do |dir|
      expect { described_class.start(%w[ApiKey], destination_root: dir) }
        .to output(/left out of ApiKey, as they look secret: digest, token, otp_secret, password_digest/).to_stdout
      file = File.read(File.join(dir, "app/wibawa/api_keys.rb"))
      expect(file).to include("search :name\n", "column :monthly_fee, as: :money\n", "column :tax_rate\n", "column :total\n", "field :monthly_fee\n")
      expect(file).not_to match(/digest|token|secret/)
    end
  end

  it "keeps the same columns out of a resource with no index or form block" do
    resource = Wibawa::Resource.new("ApiKey")
    names = resource.index_columns.map(&:name) + resource.permitted_attributes
    expect(names.map(&:to_s)).to include("name", "monthly_fee")
    expect(names.map(&:to_s) & %w[digest token otp_secret password_digest]).to eq([])
  end
end
