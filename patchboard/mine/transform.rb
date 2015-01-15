require "pp"
require "json"

def read_dat(path)
  string = File.read(path)
  category = string.slice!(0, 20)
  some_number = string.slice!(0, 10)
  questions = []
  while (line = string.slice!(0, 153)) && line.size > 0
    record = parse_line(line)
    puts JSON.pretty_generate(record)
    questions << record
  end
  questions
end

$index = {
  "1" => :a,
  "2" => :b,
  "3" => :c,
  "4" => :d,
}

def clean(string)
  string.strip.gsub(/\s+/, " ")
end

def parse_line(line)
  {
    :question => clean(line.slice(0, 70)),
    :a => clean(line.slice(72, 20)),
    :b => clean(line.slice(92, 20)),
    :c => clean(line.slice(112, 20)),
    :d => clean(line.slice(132, 20)),
    :answer => $index[line.slice(152, 1)]
  }
end


Dir["data/*.dat"].each do |path|
  filename = path.chomp(".dat") + ".json"
  data = read_dat(path)
  File.open(filename, "w") do |f|
    f.puts JSON.pretty_generate(data)
  end
end
