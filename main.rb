require 'sinatra'
require 'sqlite3'
require 'securerandom'
require 'sinatra/json'
require 'rack/auth/digest/md5'

db = SQLite3::Database.new "db/post.db"
db.results_as_hash = true

helpers do
  def protected!
    unless authorized?
      response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
      throw(:halt, [401, "Not authorized\n"])
    end
  end
  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == ['changeme', 'changeme'] 
  end
end

get '/secret?' do
  protected!
  "secret"
end

get '/' do
  posts = db.execute("SELECT * FROM posts ORDER BY id DESC")
  erb :index, { :locals => { :posts => posts } }
end

post '/' do
  file_name = ""
  if params["file"]
    ext = ""
    if params["file"][:type].include? "jpeg"
      ext = "jpg"
    elsif params["file"][:type].include? "png"
      ext = "png"
    else
      return "投稿できる画像形式はjpgとpngだけです。"
    end
    # 適当なファイル名をつける
    file_name = SecureRandom.hex + "." + ext
    
    # 画像を保存
    File.open("./public/uploads/" + file_name, 'wb') do |f|
      f.write params["file"][:tempfile].read
    end
  else
    return "画像が必須です"
  end

  stmt = db.prepare("INSERT INTO posts (text, img_file_name) VALUES(?,?)")
  stmt.bind_params(params["ex_text"], file_name)
  stmt.execute
  redirect '/'
end

get '/star/:post_id' do
  #post_id = params["post_id"].to_i
  post_id = params[:post_id].to_i
  post = db.execute("SELECT star_count FROM posts WHERE id = ?", post_id)
  if post.empty?
    return "error"
  end

  new_star_count = post[0]["star_count"] + 1
  stmt = db.prepare("UPDATE posts SET star_count = ? WHERE id = ?")
  stmt.bind_params(new_star_count, post_id)
  stmt.execute

  response = { "star_count" => new_star_count }
  json response
end
