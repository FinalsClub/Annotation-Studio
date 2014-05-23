require 'rake'
require 'mysql'
require 'net/http'
require 'json'

require 'nokogiri'
require 'open3'

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

  task :check_annotated_sections do
    begin
      con = Mysql.new('localhost', 'root', 'root', 'finalclub')
      annotated_sections = con.query('select content.section_id, content.content from content where (select count(*) from annotations where annotations.section_id = content.section_id) > 0')

      annotated_sections.each_hash do |row|
        puts "Checking section #{row['section_id']}"

        # A select few section contents include what looks like UTF-8, but
        # the Mysql gem returns the content as ASCII-8BIT. So we force the
        # encoding to UTF-8 here.
        row['content'].force_encoding(Encoding::UTF_8)

        def get_spans(doc)
          doc.xpath('.//span').select do |span|
            span['id'] =~ /word_(\d+)/
          end
        end

        script = File.expand_path('../generate_content.php', __FILE__)
        php_generated, status = Open3.capture2('php', script, row['section_id'])
        php_generated.gsub!("\r\n", "\n")
        ruby_generated, words = generate_content(row['content'])
        ruby_generated.gsub!("\r\n", "\n")

        php_parsed = Nokogiri::HTML::DocumentFragment.parse(php_generated)
        ruby_parsed = Nokogiri::HTML::DocumentFragment.parse(ruby_generated)

        php_spans = get_spans(php_parsed)
        ruby_spans = get_spans(ruby_parsed)

        if php_spans.length != ruby_spans.length
          puts "php produces #{php_spans.length} spans, ruby produces #{ruby_spans.length}"
        else
          php_spans.zip(ruby_spans) do |p, r|
            if p['id'] != r['id']
              puts "different IDs: #{p['id']} and #{r['id']}"
              break
            end

            ptext = p.text.rstrip
            rtext = r.text
            if ptext != rtext
              puts "different text for ID #{p['id']}: #{ptext.inspect} and #{rtext.inspect}"
              break
            end
          end
        end

        original_parsed = Nokogiri::HTML::DocumentFragment.parse(row['content'].gsub("\r\n", "\n"))

        if original_parsed.text != ruby_parsed.text
          puts 'original and generated are INEQUAL'
        end

        STDOUT.flush
      end
    rescue Mysql::Error => e
      puts e
    ensure
      con.close if con
    end
  end

  desc "import section from database"
  # rake import_from_thefinalclub:section[<section_id>]
  task :section, [:id] => :environment do |t, args|
    begin
      con = Mysql.new 'localhost', 'root', 'root', 'finalclub'
      rs = con.query 'SELECT * FROM `sections` where id = ' + args.id
      section = rs.fetch_hash

      work_id = section['work_id']

      rs = con.query 'SELECT * FROM `works` where id = ' + work_id
      work = rs.fetch_hash

      rs = con.query 'SELECT * FROM `content` where section_id = ' + args.id
      content = rs.fetch_hash
      if not content
        # Sections with no content are chapter headings - we can skip them.
        next
      end

      title = work['title'] + " - " + section['name']
      title.gsub!("\\'", "'")

      puts "Processing: " + title

      textContent = content['content']

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

    content, words = generate_content(document.text)
    docArray = words[1..-1].map{ |word| word.gsub(/<br \/>/, '').gsub(/&nbsp;/, ' ').gsub(/&lsquo;/, '\'').gsub(/&rsquo;/, '\'').gsub(/&mdash;/, '-') }
    puts docArray.map{ |word| '"' + word + '"'}
    begin
      con = Mysql.new 'localhost', 'root', 'root', 'finalclub'
      rs = con.query 'SELECT * FROM `annotations` where deleted_on is null and section_id = ' + args.id

      rs.each_hash do |row|
        users = con.query 'SELECT * FROM `users` where id = ' + row['user_id']
        user = users.fetch_hash
        @post_ws = "/api/annotations"

        # TODO: Dont import deleted annotations

        # 5 = "<div>".length
        startOffset = docArray[0..row['start_index'].to_i-2].join(" ").length + 5
        endOffset = docArray[0..row['end_index'].to_i-1].join(" ").length + 5

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
            :startOffset => startOffset,
            :endOffset => endOffset
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

    words.each do |word|
      addBr = false
      word.strip!

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
        i -= 2
      elsif html_started && word.index('>') == nil
        can_print_with_span = false
        i -= 1
      elsif word.index('>') != nil
        content += word[0...(word.index('>') + 1)]
        word = word[(word.index('>') + 1)..-1]
        can_print_with_span = true
        html_started = false
      end

      content_add = "#{word} "
      if can_print_with_span
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
