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
  property :file, String
  property :tags, Text
  property :created_at, DateTime

end

DataMapper.finalize.auto_upgrade!

get '/' do
  @recent = Gif.all(:limit => 10, :order => [ :created_at.desc ])

  erb :index
end

post '/submit' do
  @gif_url = params['url']

  erb :submission
end

post '/create' do
  gif_url = params['gif_url']
  #TODO: check image mimetype, check if it was added before
  md5_hash = Digest::MD5.new
  md5_hash << gif_url
  image = MiniMagick::Image.open(gif_url)
  image.write("public/catalog/#{md5_hash}.gif")

  gif = Gif.create(
    :caption    => params['caption'],
    :source     => params['gif_url'],
    :tags       => params['tags'],
    :file       => "#{md5_hash}.gif",
    :created_at => Time.now
  )

  redirect to("/gif/#{gif.id}") if gif.saved?

  "An error occurred while trying to save your submission: #{gif.errors.inspect}"
end

get '/gif/:id' do
  @gif = Gif.get(params['id'])

  erb :gif
end