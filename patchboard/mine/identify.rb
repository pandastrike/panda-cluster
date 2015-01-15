require "pp"
require "json"
require "digest/sha1"


count = 0

Dir["data/*.json"].each do |path|
  string = File.read(path)
  array = JSON.parse(string)
  array.each do |object|
    digest = Digest::SHA1.base64digest(object["question"]).tr("+", "-").tr("/", "_").chomp("=")
    pp digest
    count += 1
    object["id"] = digest
  end
  #new_path = "#{path.chomp(".json")}.id.json"
  #File.open(new_path, "w") do |f|
    #f.puts JSON.pretty_generate(array)
  #end
end

puts count
