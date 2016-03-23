require 'sinatra'
require 'data_mapper'
require 'dm-sqlite-adapter'
require 'mini_magick'
require 'digest'

DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/dev.db")

class Gif
  include DataMapper::Resource

  property :id, Serial
  property :caption, Text
  property :source, Text
  property :file, String, :required => true
  property :tags, Text
  property :created_at, DateTime

  def tag_list
    @tags.split(',')
  end
end

DataMapper.finalize.auto_upgrade!

class Submission
  attr_reader :url, :filename, :image

  def initialize(url)
    @url = url
  end

  def duplicate?
    Gif.count(:source => @url) > 0
  end

  def valid?
    @image = MiniMagick::Image.open(@url)
    @image.mime_type == "image/gif"
  end

  def save
    @filename = "#{gen_name}.gif"
    @image.write("public/catalog/#{@filename}") if valid?
  end

  def gen_name
    md5_hash = Digest::MD5.new
    md5_hash << @url
  end
end

###########
# Routes
###########

get '/' do
  @recent = Gif.all(:limit => 10, :order => [ :created_at.desc ])

  erb :index
end

post '/submit' do
  @submission = Submission.new(params['url'])

  return "This URL was already imported before." if @submission.duplicate?
  return "Invalid image type." unless @submission.valid?

  erb :submission
end

post '/create' do
  submission = Submission.new(params['gif_url'])

  return "This URL was already imported before." if submission.duplicate?
  return "Invalid image type." unless submission.valid?

  submission.save

  gif = Gif.create(
    :caption    => params['caption'],
    :source     => submission.url,
    :tags       => params['tags'],
    :file       => submission.filename,
    :created_at => Time.now
  )

  redirect to("/gif/#{gif.id}") if gif.saved?

  "An error occurred while trying to save your submission: #{gif.errors.inspect}"
end

get '/gif/:id' do
  @gif = Gif.get(params['id'])

  erb :gif
end

get '/search' do
  @search = params['search']
  @results = []
  @results = Gif.all(:tags.like => "%#{@search}%") if @search

  erb :search
end