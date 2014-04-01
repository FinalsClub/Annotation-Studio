require 'rake'
require 'mysql'
require 'net/http'
require 'json'

namespace :import_from_thefinalclub do
  # desc "import files as documents"
  # # rake file_import:html_document\["../shkspr-annotations/A Midsummer Night  's Dream 16.html"\]
  # task :html_document, [:filepath] => :environment do |t, args|
  #   file = File.join(Rails.root, args.filepath)

  #   @document = Document.new
  #   @document.title = File.basename(file)
  #   @document.author = ""
  #   # TODO: Change to specific user
  #   @document.user_id = 1
  #   # TODO: What state should it be?
  #   @document.state = "pending"
  #   @document.text = File.read(file)
  #   @document.processed_at = DateTime.now
  #   @document.save!
  # end
  desc "import section from database"
  task :section, [:id] => :environment do |t, args|
    begin
      con = Mysql.new 'localhost', 'root', 'root', 'finalclub', nil, "/Applications/MAMP/tmp/mysql/mysql.sock"
      rs = con.query 'SELECT * FROM `sections` where id = ' + args.id
      section = rs.fetch_row

      puts "Section: #{section}"
      work_id = section[1]
      puts "Work ID: #{work_id}"

      rs = con.query 'SELECT * FROM `works` where id = ' + work_id
      work = rs.fetch_row
      # puts "Work: #{work}"

      rs = con.query 'SELECT * FROM `content` where section_id = ' + args.id
      content = rs.fetch_row
      # puts "Content: #{content}"

      title = work[1] + " - " + section[3]

      puts "Processing: " + title

      @document = Document.new
      @document.title = title
      @document.author = work[2]
      # TODO: Change to specific user
      @document.user_id = 1
      # TODO: What state should it be?
      @document.state = "draft"
      @document.text = content[2]
      @document.processed_at = DateTime.now
      @document.save!

    rescue Mysql::Error => e
      puts e.errno

    ensure
      con.close if con
    end
  end

  task :section_annotations, [:id] => :environment do |t, args|
    @jwt = JWT.encode({
        :consumerKey => ENV["API_CONSUMER"],
        :userId => 'hilker.j@gmail.com',
        :issuedAt => @now,
        :ttl => 86400
      },
      ENV["API_SECRET"]
    )

    begin
      con = Mysql.new 'localhost', 'root', 'root', 'finalclub', nil, "/Applications/MAMP/tmp/mysql/mysql.sock"
      rs = con.query 'SELECT * FROM `annotations` where section_id = ' + args.id

      while row = rs.fetch_row do
        puts row
        test = row
      end

      @post_ws = "/api/annotations"

      @payload = {
        # user: req.body.user,
        # username: req.body.username,
        # consumer: "annotationstudio.mit.edu",
        # annotator_schema_version: req.body.annotator_schema_version,
        :text => test[7],
        :uri => "http://localhost:3000/documents/hamlet-act-iv-scene-i-a-room-in-the-castle",
        # src: req.body.src,
        :quote => test[5],
        # tags: req.body.tags,
        :groups => ["public"],
        # subgroups: req.body.subgroups,
        :uuid => SecureRandom.urlsafe_base64,
        :ranges => [{
          :start => "N/A",
          :end => "N/A",
          :startOffset => test[3],
          :endOffset => test[4]
        }],
        # shapes: req.body.shapes,
        # permissions: req.body.permissions,
        :legacy => true
      }.to_json


      req = Net::HTTP::Post.new(@post_ws, initheader = {'Content-Type' =>'application/json', 'x-annotator-auth-token' => @jwt})
      req.body = @payload
      response = Net::HTTP.new('localhost', '5000').start {|http| http.request(req) }
      puts "Response #{response.code} #{response.message}: #{response.body}"

    rescue Mysql::Error => e
      puts e.errno

    ensure
      con.close if con
    end
  end
end
