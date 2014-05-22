require 'rake'
require 'mysql'
require 'net/http'
require 'json'

namespace :import_from_thefinalclub do

  desc "import all works from thefinalclub database"
  # rake import_from_thefinalclub:all_works
  task :all_works => :environment do
    begin
      con = Mysql.new 'localhost', 'root', 'root', 'finalclub'
      works = con.query 'SELECT * FROM `works`'

      works.each_hash do |work|
          Rake::Task["import_from_thefinalclub:work"].invoke(work["id"])
          Rake::Task["import_from_thefinalclub:work"].reenable
      end

    rescue Mysql::Error => e
      puts e

    ensure
      con.close if con
    end
  end

  desc "import a work"
  # rake import_from_thefinalclub:work[<work_id>]
  task :work, [:id] => :environment do |t, args|
    begin
      con = Mysql.new 'localhost', 'root', 'root', 'finalclub'
      sections = con.query 'SELECT * FROM `sections` where work_id = ' + args.id

      sections.each_hash do |section|
        annotations = con.query 'SELECT * FROM `annotations` where section_id = ' + section["id"]
        if annotations.num_rows > 0
          # Rake::Task["import_from_thefinalclub:section"].invoke(section["id"])
          # Rake::Task["import_from_thefinalclub:section"].reenable
          Rake::Task["import_from_thefinalclub:section_annotations"].invoke(section["id"])
          Rake::Task["import_from_thefinalclub:section_annotations"].reenable
        end
      end

    rescue Mysql::Error => e
      puts e

    ensure
      con.close if con
    end
  end

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
  # rake import_from_thefinalclub:section[<section_id>]
  task :section, [:id] => :environment do |t, args|
    begin
      con = Mysql.new 'localhost', 'root', 'root', 'finalclub'
      rs = con.query 'SELECT * FROM `sections` where id = ' + args.id
      section = rs.fetch_hash

      # puts "Section: #{section}"
      work_id = section['work_id']
      # puts "Work ID: #{work_id}"

      rs = con.query 'SELECT * FROM `works` where id = ' + work_id
      work = rs.fetch_hash
      # puts "Work: #{work}"

      rs = con.query 'SELECT * FROM `content` where section_id = ' + args.id
      content = rs.fetch_hash
      # puts "Content: #{content}"

      title = work['title'] + " - " + section['name']
      title.gsub!("\\'", "'")

      puts "Processing: " + title

      # Some dont have content. This dies.  Should fix
      if content
        textContent = content['content']
        # textContent.gsub!('<a>', '')
        # textContent.gsub!('</a>', '')

        # textContent.gsub!(/\r\n/, '')
        # textContent.gsub!(/<br \/>/, '<br/>')

        @document = Document.new
        @document.title = title
        @document.author = work['author']
        # TODO: Change to specific user
        @document.user_id = 1
        # TODO: What state should it be?
        @document.state = "published"
        @document.text = textContent
        @document.processed_at = DateTime.now
        @document.final_club_id = args.id
        @document.final_club_work_id = work_id
        @document.save!
      end

    rescue Mysql::Error => e
      puts e.errno

    ensure
      con.close if con
    end
  end

  desc "import section's annotations from database"
  # rake import_from_thefinalclub:section_annotations[<section_id>]
  task :section_annotations, [:id] => :environment do |t, args|
    @jwt = JWT.encode({
        :consumerKey => ENV["API_CONSUMER"],
        :userId => 'atrigent@gmail.com',
        :issuedAt => @now,
        :ttl => 86400
      },
      ENV["API_SECRET"]
    )

    document = Document.where(:final_club_id => args.id).first

    if !document
      puts "Document isn't in database (Probably had no content)"
      next
    end

    # if Document.last.text.scan(/<blockquote>|<h3>/).length != 0
    #   puts "Blockquote or h3 found for section: #{args.id}"
    #   next
    # end

    # +5 is <div>
    # "startOffset": 5654,
    # "endOffset": 5672,
    # startOffset = document.text.gsub(/<br \/>/, '').gsub(/&nbsp;/, ' ').enum_for(:scan, /Harry/).map { Regexp.last_match.begin(0) }.first+5
    # endOffset = document.text.gsub(/<br \/>/, '').gsub(/&nbsp;/, ' ').enum_for(:scan, /sitting/).map { Regexp.last_match.begin(0) }.last+5
    # docArray = document.text.gsub(/\t /, "\t").split(/<p>\r\n| |\r\n/).reject{|word| word =~ /^<\/p>$/i}
    #docArray = document.text.scan(/<br \/>|\S+<br \/>|\S+<\/p>|\S+<\/blockquote>|\S+<blockquote>|\S+ ?/).map{ |word| word.gsub(/<br \/>/, '').gsub(/&nbsp;/, ' ').gsub(/&lsquo;/, '\'').gsub(/&rsquo;/, '\'').gsub(/&mdash;/, '-').gsub(/<.*?>/, '') }#.gsub(/<p>/, '').gsub(/<\/p>/, '') }
    # docArray = document.text.scan(/<br\/>|\S+<br\/>|\S+<\/p>|\S+<\/blockquote>|\S+<blockquote>|\S+ ?/).map{ |word| word.gsub(/<br\/>/, '').gsub(/&nbsp;/, ' ').gsub(/&lsquo;/, '\'').gsub(/&rsquo;/, '\'').gsub(/&mdash;/, '-').gsub(/<.*?>/, '') }



    content, words = generate_content(document.text)
    docArray = words[1..-1].map{ |word| word.gsub(/<br \/>/, '').gsub(/&nbsp;/, ' ').gsub(/&lsquo;/, '\'').gsub(/&rsquo;/, '\'').gsub(/&mdash;/, '-') }
    # docArray[1..-1].map! do |word|
    #   # if word word.length
    #     word.gsub(/<br \/>/, '')
    #         .gsub(/&nbsp;/, ' ')
    #         .gsub(/&lsquo;/, '\'')
    #         .gsub(/&rsquo;/, '\'')
    #         .gsub(/&mdash;/, '-')
    #   # end
    # end
    puts docArray.map{ |word| '"' + word + '"'}
    # docArray = document.text.scan(/<br\/>&nbsp;[^\s<>]+ ?|<br\/>|[^\s<>]+ ?/).map{ |word| word.gsub(/<br\/>/, '').gsub(/&nbsp;/, ' ').gsub(/&lsquo;/, '\'').gsub(/&rsquo;/, '\'').gsub(/&mdash;/, '-') }
    begin
      con = Mysql.new 'localhost', 'root', 'root', 'finalclub'
      rs = con.query 'SELECT * FROM `annotations` where deleted_on is null and section_id = ' + args.id

      rs.each_hash do |row|
        users = con.query 'SELECT * FROM `users` where id = ' + row['user_id']
        user = users.fetch_hash
        @post_ws = "/api/annotations"

        # TODO: Dont import deleted annotations

        # startOffset = docArray[0..test[3].to_i-3].join(" ").gsub(/ \t | \t|\t /, "\t").gsub(/ \t/, "\t").length

        # 5 = "<div>".length
        startOffset = docArray[0..row['start_index'].to_i-2].join(" ").length + 5
        endOffset = docArray[0..row['end_index'].to_i-1].join(" ").length + 5#

        @payload = {
          :user => user['username'],
          :username => user['username'],
          # consumer: "annotationstudio.mit.edu",
          # annotator_schema_version: req.body.annotator_schema_version,
          :text => row['annotation'],
          :uri => document.slug,
          # src: req.body.src,
          :quote => row['quote'],
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
        # response = Net::HTTP.new('annotorious-store.herokuapp.com').start {|http| http.request(req) }
        # puts "Response #{response.code} #{response.message}: #{response.body}"
      end

      puts "Imported section: #{args.id}"

    rescue Mysql::Error => e
      puts e.errno

    ensure
      con.close if con
    end
  end

  def magic_no
    '####)(@*#)$*@!' # because wtf
  end

  def prepare_content(content)
    content.gsub('<br />', "#{magic_no} ")
           .gsub('>', '> ')
           .gsub('</', ' </')
  end

  def get_words(content)
    prepare_content(content).split(' ')
  end

  def prepare_word(word)
    word.gsub(magic_no, '<br />')
        .gsub('<a>', '')
        .gsub('</a>', '')
        .strip
  end

  def word_is_html(word)
    word[0] == '<' && word[-1] == '>'
  end

  def generate_content(section_content)
    words = get_words(section_content)
    words_raw = []
    content = ''
    i = 0
    can_print_with_span = true
    html_started = false

    # puts wordsSplit.map{ |word| '"' + word + '"'}

    words.each do |word|
      # puts word
      addBr = false
      word = word.strip

      next if word.empty?

      if word_is_html(word)
        content += word
        next
      end

      i+=1
      word = prepare_word(word)

      addBr = word.index('<br />') != nil
      word.gsub!('<br />', '')

      if word[0] == '<' && word.index('>') == nil
        can_print_with_span = false
        html_started = true
        i-=2
      elsif html_started && word.index('>') == nil
        can_print_with_span = false
        i-=1
      elsif word.index('>') != nil
        content += word[0...(word.index('>') + 1)]
        word = word[(word.index('>') + 1)..-1]
        can_print_with_span = true
        html_started = false
      end

      content_add = "#{word} "
      if can_print_with_span
        # puts "Concating: " + word
        content += "<span id=\"word_#{i}\">#{content_add}</span>"
        words_raw[i] = word
      else
        content += content_add
      end

      if addBr
        content += '<br />'
        words_raw[i] += '<br />'
      end
    end
    return content, words_raw

  end
end
# gsub(/\t /, "\t").split(/<p>\r\n| |\r\n/).reject{|word| word =~ /^<\/p>$/i}
# Document.last.text.split(/<p>\r\n\t| |\r\n/).reject{|word| word =~ /^\t$|^<\/p>$/i}[test[3]-2..test[4]-2]
