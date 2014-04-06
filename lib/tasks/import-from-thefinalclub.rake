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

      # Some dont have content. This dies.  Should fix
      textContent = content[2]
      textContent.gsub!('<a>', '')
      textContent.gsub!('</a>', '')
      # textContent.gsub!(/\r\n\t  /, '')
      # textContent.gsub!(/\r\n\t/, '')
      # textContent.gsub!(/\r\n/, '')

      @document = Document.new
      @document.title = title
      @document.author = work[2]
      # TODO: Change to specific user
      @document.user_id = 1
      # TODO: What state should it be?
      @document.state = "published"
      @document.text = textContent
      @document.processed_at = DateTime.now
      @document.final_club_id = args.id
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

    document = Document.where(:final_club_id => args.id).first
    # +5 is <div>
    # "startOffset": 5654,
    # "endOffset": 5672,
    # startOffset = document.text.gsub(/<br \/>/, '').gsub(/&nbsp;/, ' ').enum_for(:scan, /Harry/).map { Regexp.last_match.begin(0) }.first+5
    # endOffset = document.text.gsub(/<br \/>/, '').gsub(/&nbsp;/, ' ').enum_for(:scan, /sitting/).map { Regexp.last_match.begin(0) }.last+5
    # docArray = document.text.gsub(/\t /, "\t").split(/<p>\r\n| |\r\n/).reject{|word| word =~ /^<\/p>$/i}
    docArray = document.text.scan(/<br \/>|\S+<br \/>|\S+ ?/).map{ |word| word.gsub(/<br \/>/, '').gsub(/&nbsp;/, ' ') }

    begin
      con = Mysql.new 'localhost', 'root', 'root', 'finalclub', nil, "/Applications/MAMP/tmp/mysql/mysql.sock"
      rs = con.query 'SELECT * FROM `annotations` where section_id = ' + args.id

      while row = rs.fetch_row do
        users = con.query 'SELECT * FROM `users` where id = ' + row[1]
        user = users.fetch_row
        @post_ws = "/api/annotations"

        # startOffset = docArray[0..test[3].to_i-3].join(" ").gsub(/ \t | \t|\t /, "\t").gsub(/ \t/, "\t").length
        startOffset = docArray[0..row[3].to_i-2].join("").length + 5
        endOffset = docArray[0..row[4].to_i-1].join("").length + 5#

        @payload = {
          :user => user[7],
          :username => user[7],
          # consumer: "annotationstudio.mit.edu",
          # annotator_schema_version: req.body.annotator_schema_version,
          :text => row[7],
          :uri => document.slug,
          # src: req.body.src,
          :quote => row[5],
          # tags: req.body.tags,
          :groups => ["public"],
          # subgroups: req.body.subgroups,
          :uuid => SecureRandom.urlsafe_base64,
          :ranges => [{
            :start => '/div',
            :end => '/div',
            :startOffset => startOffset,#test[3],
            :endOffset => endOffset#[test4]
          }],
          # shapes: req.body.shapes,
          :permissions => {
            :read => ['andrew@finalsclub.org'],
            :update => ['andrew@finalsclub.org'],
            :delete => ['andrew@finalsclub.org'],
            :admin => ['andrew@finalsclub.org']
          },
          :legacy => true
        }.to_json


        req = Net::HTTP::Post.new(@post_ws, initheader = {'Content-Type' =>'application/json', 'x-annotator-auth-token' => @jwt})
        req.body = @payload
        response = Net::HTTP.new('localhost', '5000').start {|http| http.request(req) }
        puts "Response #{response.code} #{response.message}: #{response.body}"
      end

    rescue Mysql::Error => e
      puts e.errno

    ensure
      con.close if con
    end
  end
end
# gsub(/\t /, "\t").split(/<p>\r\n| |\r\n/).reject{|word| word =~ /^<\/p>$/i}
# Document.last.text.split(/<p>\r\n\t| |\r\n/).reject{|word| word =~ /^\t$|^<\/p>$/i}[test[3]-2..test[4]-2]
