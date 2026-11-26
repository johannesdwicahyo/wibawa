require "spec_helper"
require "yaml"

# Every locale file says the same things as English, and the code asks for nothing English lacks.
RSpec.describe "Wibawa locale files" do
  flatten = lambda do |hash, prefix = nil|
    hash.flat_map { |key, value| value.is_a?(Hash) ? flatten.(value, [ prefix, key ].compact.join(".")).to_a : [ [ [ prefix, key ].compact.join("."), value ] ] }.to_h
  end

  locales = Dir["config/locales/*.yml"].to_h { |file| [ File.basename(file, ".yml"), flatten.(YAML.load_file(file).values.first) ] }
  english = locales.fetch("en")
  # Plural forms differ by language (Indonesian has only "other"), so a count key is compared by its parent.
  plural = ->(key) { key.sub(/\.(zero|one|two|few|many|other)\z/, "") }
  variables = ->(text) { text.to_s.scan(/%\{(\w+)\}/).flatten.sort.uniq }

  it "has a file whose top key is its own name, for every locale" do
    Dir["config/locales/*.yml"].each { |file| expect(YAML.load_file(file).keys).to eq([ File.basename(file, ".yml") ]) }
  end

  (locales.keys - [ "en" ]).each do |name|
    describe name do
      let(:keys) { locales[name] }

      it "has every English key, and no other" do
        missing = english.keys.map(&plural).uniq - keys.keys.map(&plural)
        extra = keys.keys.map(&plural).uniq - english.keys.map(&plural)
        expect(missing).to be_empty, "missing from #{name}.yml: #{missing.join(', ')}"
        expect(extra).to be_empty, "in #{name}.yml but not in en.yml: #{extra.join(', ')}"
      end

      it "leaves nothing empty and uses the same %{variables}" do
        expect(keys.select { |_, text| text.to_s.strip.empty? }.keys).to eq([])
        differing = (keys.keys & english.keys).reject { |key| variables.(keys[key]) == variables.(english[key]) }
        expect(differing).to eq([])
      end
    end
  end

  it "defines in English every key the code asks for by name" do
    used = Dir["app/**/*.{rb,erb}", "lib/**/*.{rb,tt}"].flat_map do |file|
      File.read(file).scan(/\bt\(\s*["'](wibawa\.[\w.]+)["']/).flatten.map { |key| [ key, file ] }
    end
    missing = used.reject { |key, _| english.key?(key) || english.keys.any? { |known| plural.(known) == key } }
    expect(used.size).to be > 100 # the scan still finds the calls
    expect(missing.map { |key, file| "#{key} (#{file})" }.uniq).to eq([])
  end

  it "keeps no English key the code never asks for" do
    source = Dir["app/**/*.{rb,erb,js}", "lib/**/*.{rb,tt}"].map { |file| File.read(file) }.join("\n")
    built = source.scan(/["'](wibawa\.[\w.]*)#\{/).flatten.uniq # "wibawa.import.#{action}": any key under it counts as used
    unused = english.keys.map(&plural).uniq.reject do |key|
      source.include?(%("#{key}")) || source.include?("'#{key}'") || built.any? { |prefix| key.start_with?(prefix) }
    end
    expect(unused).to be_empty, "in en.yml but never used: #{unused.join(', ')}"
  end
end
