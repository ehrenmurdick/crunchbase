# encoding: UTF-8

require 'open-uri'
require 'progressbar'
require 'json'
require 'csv'

class << nil
  def try(key)
    nil
  end
end

class Hash
  def try(key)
    self[key]
  end
end

class InvalidCompany < StandardError
end

class Company
  def self.header
    %w{Name URL Description Seed A B C Seed A B C}
  end

  def row
    [name, plain_url, description, seedAmt, *roundAmts, seedDate, *roundDates]
  end

  def rounds
    ('a'..'c').map do |l|
      yield l
    end
  end

  def roundAmts
    rounds do |l|
     roundAmt(l)
    end
  end

  def roundDates
    rounds do |l|
     roundDate(l)
    end
  end


  attr_accessor :name, :url, :data, :plain_url
  attr_reader :valid
  def initialize(name, url)
    @name, @plain_url = name, url
    if @plain_url
      self.url = "http://api.crunchbase.com/v/1/company/#{File.basename(@plain_url)}.js"
    end
  end

  def fetch!
    JSON.parse(open(url).read)
  rescue JSON::ParserError
    raise InvalidCompany
  end

  def data
    @data ||= fetch!
  end

  def [](key)
    data[key]
  end

  def description
    self['overview']
  end

  def seedAmt
    roundAmt('seed')
  end

  def seedDate
    roundDate('seed')
  end

  # a, b, c
  def roundAmt(letter)
    str = round(letter).try("raised_amount")

    if (curr = round(letter).try("raised_currency_code")) != 'USD'
      "#{str} #{curr}"
    end
    str
  end

  def roundDate(letter)
    "#{round(letter).try("funded_month")}/#{round(letter).try("funded_day")}/#{round(letter).try("funded_year")}"
  end

  def round(letter)
    @rounds_hash ||= {}
    @rounds_hash[letter] ||= self["funding_rounds"].find do |x|
      x["round_code"] == letter    
    end
  end

end

lines = File.readlines("Index.csv")
pbar = ProgressBar.new("companies", lines.count)
File.open("output.csv", "w") do |f|
  f.write(CSV.generate_line(Company.header))
  lines.each do |line|
    pbar.inc
    begin
      line = line.split(',')
      company = Company.new(*line[0,2])
      f.write(CSV.generate_line(company.row))
    rescue InvalidCompany, URI::InvalidURIError, ArgumentError
      next
    end
  end
end
pbar.finish
