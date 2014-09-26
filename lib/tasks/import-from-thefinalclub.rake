require 'rake'
require 'mysql2'
require 'net/http'
require 'json'

require 'nokogiri'
require 'open3'

require 'phuby'

require 'mongo'

namespace :import_from_thefinalclub do
  def init_mysql
    Mysql2::Client.new(host: 'localhost', username: 'root', password: 'root', database: 'finalclub')
  end

  desc "import all works from thefinalclub database"
  # rake import_from_thefinalclub:all_works
  task :all_works => :environment do
    con = init_mysql
    works = con.query 'SELECT * FROM `works`'

    works.each do |work|
      Rake::Task["import_from_thefinalclub:work"].invoke(work["id"])
      Rake::Task["import_from_thefinalclub:work"].reenable
    end
  end

  desc "import a work"
  # rake import_from_thefinalclub:work[<work_id>]
  task :work, [:id] => :environment do |t, args|
    con = init_mysql
    sections = con.query "SELECT * FROM `sections` where work_id = #{args.id}"

    sections.each_hash do |section|
      Rake::Task["import_from_thefinalclub:section"].invoke(section["id"])
      Rake::Task["import_from_thefinalclub:section"].reenable
    end
  end

  task :check_annotated_sections do
    con = init_mysql
    annotated_sections = con.query('select content.section_id, content.content from content where (select count(*) from annotations where annotations.section_id = content.section_id) > 0')

    annotated_sections.each do |row|
      puts "Checking section #{row['section_id']}"

      def get_spans(doc)
        doc.xpath('.//span').select do |span|
          span['id'] =~ /word_(\d+)/
        end
      end

      script = File.expand_path('../generate_content.php', __FILE__)
      php_generated, status = Open3.capture2('php', script, row['section_id'].to_s)
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
  end

  def stripslashes(str)
    Phuby::Runtime.php do |rt|
      rt['x'] = str
      rt.eval('$x = stripslashes($x);')

      rt['x']
    end
  end

  desc "import section from database"
  # rake import_from_thefinalclub:section[<section_id>]
  task :section, [:id] => :environment do |t, args|
    con = init_mysql
    rs = con.query "SELECT * FROM `sections` where id = #{args.id}"
    section = rs.first

    work_id = section['work_id']

    rs = con.query "SELECT * FROM `works` where id = #{work_id}"
    work = rs.first

    rs = con.query "SELECT * FROM `content` where section_id = #{args.id}"
    content = rs.first
    if not content
      # Sections with no content are chapter headings - we can skip them.
      next
    end

    title = stripslashes(work['title']) + " - " + stripslashes(section['name'])

    puts "Processing: " + title

    textContent = content['content']

    @document = Document.new
    @document.title = title
    @document.author = stripslashes(work['author'])
    # TODO: Change to specific user
    @document.user_id = 1
    # TODO: What state should it be?
    @document.state = "published"
    @document.text = textContent
    @document.processed_at = DateTime.now
    @document.final_club_id = args.id
    @document.final_club_work_id = work_id
    @document.save!

    Rake::Task["import_from_thefinalclub:section_annotations"].invoke(args.id)
    Rake::Task["import_from_thefinalclub:section_annotations"].reenable
  end

  def is_content(content)
    if not content or content == '' or content == '<br />'
      return false
    end

    Phuby::Runtime.php do |rt|
      rt['content'] = content

      rt.eval('$x = strlen(strip_tags(trim($content))) > 0;')

      rt['x']
    end
  end

  task :check_is_content do
    con = init_mysql
    rs = con.query 'select * from content'

    rs.each do |row|
      if not is_content(row['content'])
        puts "content of section #{row['section_id']} is degenerate"
        puts row['content'].inspect
      end
    end
  end

  def get_parents(work_sections, cur_section)
    ancestors = []

    while cur_section
      ancestors.unshift(cur_section)

      cur_section = work_sections.find do |section|
        section['id'] == cur_section['parent_id']
      end
    end

    root = ancestors[0]
    if root['parent_id']
      puts "weirdness: could not find section #{root['parent_id']}, parent of section #{root['id']}, in work #{root['work_id']}"
      return nil
    end

    ancestors
  end

  def show_work_hierarchies(con, id)
    work_sections = []
    con.query("select sections.*, content.content, section_parents.parent_id from sections " \
              "left join content on sections.id = content.section_id " \
              "left join section_parents on sections.id = section_parents.child_id " \
              "where work_id = #{id} order by `order` asc, sections.id asc").each do |row|
      work_sections << row
    end

    last_ancestors = []
    work_sections.each do |section|
      ancestors = get_parents(work_sections, section)
      next unless ancestors

      if ancestors.length - 1 > last_ancestors.length
        puts "weirdness: increase of more than one level from previous entry!"
      end

      if ancestors.length > last_ancestors.length and
         ancestors.take(last_ancestors.length) != last_ancestors
        puts "weirdness: not a child of previous entry!"
      elsif ancestors.length <= last_ancestors.length and
            ancestors[0..-2] != last_ancestors.take(ancestors.length-1)
        puts "weirdness: ancestors changed suddenly!"
      end

      output = "\t" * (ancestors.length - 1) + ancestors.map { |s| s['id'].to_s + ', ' }.join('')
      cur =  stripslashes(ancestors[-1]['name'])
      if ancestors.length > 1
        prev = stripslashes(ancestors[-2]['name'])
        prefix = "#{prev},"
        if cur.starts_with?(prefix)
          if cur.scan(prefix).length > 1
            puts 'weirdess: more than one "prefix"'
          end

          if cur.index(prefix) != 0
            puts 'weirdness: "prefix" not at beginning of string'
          end

          output += cur.gsub(prefix, '').inspect + ', real name: ' + cur.inspect
        else
          output += cur.inspect + ', no prefixing'
        end
      else
        output += cur.inspect
      end

      if is_content(ancestors[-1]['content'])
        if work_sections.any? { |section| section['parent_id'] == ancestors[-1]['id'] }
          puts "weirdness: the following section heading has content!"
        end

        output += ", has content"
      end

      puts output
      last_ancestors = ancestors
    end
  end

  task :show_work_hierarchy, :id do |t, args|
    con = init_mysql

    show_work_hierarchies(con, args.id.to_i)
  end

  task :show_work_hierarchies do
    con = init_mysql

    con.query('select id from works').each do |work|
      puts "work id: #{work['id']}"
      show_work_hierarchies(con, work['id'].to_i)
    end
  end

  def interpret_linkee_type(type, collections)
    case type
      when 'section'
        ['sections', collections[:contents]]
      when 'work'
        ['works', collections[:works]]
      when 'annotation'
        ['annotations', collections[:annotations]]
      else
        puts "unknown linkee type #{type}"
        nil
    end
  end

  def migrate_annotation_links(con, annotation_id, mongo_id, collections)
    links = con.query("select * from annotation_links where annotation_linker_id = #{annotation_id}")

    links.each do |link|
      linkee_id = link['linkee_id']
      linkee_type = link['linkee_type']

      table = interpret_linkee_type(linkee_type, collections)
      next if table.nil?
      table = table[0]

      if con.query("select id from #{table} where id = #{linkee_id}").count.zero?
        puts "link #{link['id']} points to nonexistent #{linkee_type} #{linkee_id}, skipping"
        next
      end

      if linkee_type == 'section'
        content = con.query("select * from content where section_id = #{linkee_id}").first
        if not content or not is_content(content['content'])
          puts "link #{link['id']} points to nonexistent or empty section #{linkee_id}, skipping"
          next
        end
      end

      collections[:links].insert({
        legacy_id: link['id'],
        linker: BSON::DBRef.new(collections[:annotations].name, mongo_id),
        legacy_linkee: {
          type: linkee_type,
          id: linkee_id
        },
        reason: link['reason'].strip,
        relationship: {
          1 => 'influenced',
          2 => 'influenced_by',
          3 => 'interpretation'
        }[link['relationship']]
      })
    end
  end

  def migrate_section_annotations(con, text, section_id, content_id, collections)
    migrated = migrate_annotations(con, text, section_id)

    migrated.each do |id, annotator_obj|
      mongo_id = collections[:annotations].insert({
        content_id: content_id,
        legacy_id: id,
        annotation: annotator_obj
      })

      migrate_annotation_links(con, id, mongo_id, collections)
    end

    return migrated.length
  end

  def migrate_sections(con, work, mongo_work, collections, section_parent=nil)
    parent_check = "parent_id " +
      if section_parent
        "= #{section_parent['id']}"
      else
        "is NULL"
      end

    rs = con.query("select sections.*, content.id as content_id, content.content from sections " \
                   "left join section_parents on sections.id = child_id " \
                   "left join content on sections.id = content.section_id " \
                   "where work_id = #{work} and #{parent_check} " \
                   "order by `order` asc, sections.id asc")

    ret = []
    annos = 0

    rs.each do |section|
      name = section['name']
      if section_parent
        name = name.sub(/^#{section_parent['name']},/, '')
      end

      obj = {
        name: Nokogiri::HTML(stripslashes(name)).text.strip,
        legacy_id: section['id']
      }

      children, child_annos = migrate_sections(con, work, mongo_work, collections, section)
      if not children.empty?
        obj[:subSections] = children
        annos += child_annos
      end

      if is_content(section['content'])
        obj[:content_id] = collections[:contents].insert({
          work_id: mongo_work,
          legacy_id: section['content_id'],
          html: section['content']
        })

        annos += migrate_section_annotations(con,
                                             section['content'],
                                             section['id'],
                                             obj[:content_id],
                                             collections)
      end

      ret << obj
    end

    return ret, annos
  end

  def migrate_work(con, id, collections)
    work = con.query("select * from works where id = #{id}").first

    year = work['year']
    if year == 0
      year = nil
    end

    intro = work['intro_essay']
    if intro and not intro.empty?
      intro = stripslashes(intro)
    else
      intro = nil
    end

    summary = work['summary']
    if summary and not summary.empty?
      summary = Nokogiri::HTML(stripslashes(work['summary'])).text.strip
    else
      summary = nil
    end

    work_id = collections[:works].insert({
      title: stripslashes(work['title']).strip,
      author: Nokogiri::HTML(stripslashes(work['author'])).text.strip,
      summary: summary,
      introEssay: intro,
      year: year,
      pageViews: work['page_views'],
      createdAt: work['created_on'],
      legacy_id: id
    })

    sections, num_annos = migrate_sections(con, id, work_id, collections)

    collections[:works].update({ _id: work_id }, { '$set' => {
      annotationsCount: num_annos,
      sections: sections,
    }})
  end

  task :resolve_links, :uri do |t, args|
    con = init_mysql
    collections = init_mongo(args.uri)

    resolve_links(con, collections)
  end

  def resolve_links(con, collections)
    unresolved_links = collections[:links].find({ linkee: { '$exists' => false } },
                                                { fields: { legacy_linkee: 1 } })

    unresolved_links.each do |link|
      legacy = link['legacy_linkee']
      collection = interpret_linkee_type(legacy['type'], collections)
      next if collection.nil?
      collection = collection[1]

      legacy_id = legacy['id']
      if legacy['type'] == 'section'
        # need to use the corresponding content id, since we are now linking with a content
        content = con.query("select id from content where section_id = #{legacy_id}").first
        legacy_id = content['id']
      end

      linkee = collection.find_one({ legacy_id: legacy_id },
                                   { fields: {} })

      if linkee
        collections[:links].update({ _id: link['_id'] }, { '$set' => {
          linkee: BSON::DBRef.new(collection.name, linkee['_id'])
        }})

        puts "resolved link #{link['_id']} to #{collection.name} #{linkee['_id']}"
      end
    end
  end

  def pop_docs(collection, query)
    collection.find(query).each do |doc|
      yield doc
    end
    collection.remove(query)
  end

  task :unmigrate_work, [:id, :uri] do |t, args|
    collections = init_mongo(args.uri)

    pop_docs(collections[:works], { legacy_id: args.id.to_i }) do |work|
      pop_docs(collections[:contents], { work_id: work['_id'] }) do |content|
        pop_docs(collections[:annotations], { content_id: content['_id'] }) do |annotation|
          ref = BSON::DBRef.new(collections[:annotations].name, annotation['_id'])
          collections[:links].remove({ linker: ref })
          collections[:links].update({ linkee: ref },
                                     { '$unset' => { linkee: nil } },
                                     { multi: true })
        end
      end
    end
  end

  def init_mongo(uri)
    db = Mongo::MongoClient.from_uri(uri).db

    return {
      works: db.collection('works'),
      contents: db.collection('sectionContents'),
      annotations: db.collection('annotations'),
      links: db.collection('links')
    }
  end

  task :migrate_to_mongo, [:id, :uri] do |t, args|
    con = init_mysql
    collections = init_mongo(args.uri)

    migrate_work(con, args.id, collections)
  end

  task :migrate_range_to_mongo, [:start, :length, :uri] do |t, args|
    con = init_mysql

    query = "select id from works where id >= #{args.start} order by id"
    if args.length.to_i != -1
      query += " limit #{args.length}"
    end

    collections = init_mongo(args.uri)
    con.query(query).each do |work|
      puts "migrating work #{work['id']}..."
      migrate_work(con, work['id'], collections)
    end
  end

  task :wipe_mongo, :uri do |t, args|
    3.downto(1) do |x|
      print "\rWIPING DATABASE IN #{x}..."
      sleep(1)
    end
    puts

    init_mongo(args.uri).each_pair do |k, v|
      puts "dropping collection #{k}..."
      v.drop
    end
  end

  def migrate_annotations(con, text, id, start_offset=0)
    def word_span?(node)
      node and node.element? and node.name == 'span' and node['id'] =~ /^word_\d+$/
    end

    generated = generate_content(text)[0]
    generated.gsub!("\r\n", "\n")
    frag = Nokogiri::HTML::DocumentFragment.parse(generated)

    frag.search('span').each do |span|
      if word_span?(span) and span.search('text()').length == 0
        span << Nokogiri::XML::Text.new('', frag.document)
      end
    end

    cur_len = 0
    starts = Hash.new { |h, k| h[k] = [] }
    last_span = nil
    frag.search('text()').each do |txt|
      p = txt.parent

      if word_span?(p) and p != last_span
        starts[p['id']] << [cur_len, cur_len + p.text.length]

        last_span = p
      end

      cur_len += txt.text.length
    end

    rs = con.query "SELECT * FROM `annotations` where deleted_on is null and section_id = #{id}"
    annotation_objects = []

    rs.each do |row|
      next unless row['deleted_on'].nil?

      users = con.query "SELECT * FROM `users` where id = #{row['user_id']}"
      user = users.first

      startOffset = starts["word_#{row['start_index']}"]
      endOffset = starts["word_#{row['end_index']}"]

      if startOffset.length > 1 or endOffset.length > 1
        puts "on a duplicated span number"
        next
      end

      annotation_objects << [row['id'], {
        :user => user['username'],
        :username => user['username'],
        # consumer: "annotationstudio.mit.edu",
        # annotator_schema_version: req.body.annotator_schema_version,
        :text => row['annotation'],
        # src: req.body.src,
        :quote => row['quote'],
        # tags: req.body.tags,
        :groups => ["public"],
        # subgroups: req.body.subgroups,
        :uuid => SecureRandom.urlsafe_base64,
        :ranges => [{
          :start => '/div',
          :end => '/div',
          :startOffset => startOffset[0][0] + start_offset,
          :endOffset => endOffset[0][1] + start_offset
        }],
        # shapes: req.body.shapes,
        :permissions => {
          :read => ['andrew@finalsclub.org'],
          :update => ['andrew@finalsclub.org'],
          :delete => ['andrew@finalsclub.org'],
          :admin => ['andrew@finalsclub.org']
        }
      }]
    end

    return annotation_objects
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

    con = init_mysql
    @post_ws = "/api/annotations"
    # A little bit of whitespace in the view throws
    # off our numbers by 5 characters.
    migrate_annotations(con, document.text, args.id, 5).each do |id, obj|
      obj[:uri] = document.slug
      obj[:legacy_id] = id

      req = Net::HTTP::Post.new(@post_ws, initheader = {'Content-Type' =>'application/json', 'x-annotator-auth-token' => @jwt})
      req.body = obj.to_json
      response = Net::HTTP.new('localhost', '5000').start {|http| http.request(req) }
      # response = Net::HTTP.new('annotorious-store.herokuapp.com').start {|http| http.request(req) }
      # puts "Response #{response.code} #{response.message}: #{response.body}"
    end

    puts "Imported section: #{args.id}"

  end

  def magic_no
    '####)(@*#)$*@!' # because wtf
  end

  def added_whitespace
    "\ue000"
  end

  def prepare_content(content)
    content.gsub('<br />', "#{magic_no}#{added_whitespace}")
           .gsub('>', ">#{added_whitespace}")
           .gsub('</', "#{added_whitespace}</")
  end

  def get_words(content)
    split = prepare_content(content).split(/(?= |#{added_whitespace})|(?<= |#{added_whitespace})/)

    words = [[]]
    split.each do |s|
      next if s == added_whitespace

      if s == ' '
        words[-1] << s
      else
        words << [s]
      end
    end

    return words
  end

  def prepare_word(word)
    word.gsub(magic_no, '<br />')
        .gsub('<a>', '')
        .gsub('</a>', '')
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

    content += words[0].join('')

    words[1..-1].each do |(word, *whitespace)|
      addBr = false
      matches = word.match(/\A(\s*).*?(\s*)\z/m)
      word.strip!

      if word.empty?
        content += matches[1] + matches[2] + whitespace.join('')
        next
      end

      if word_is_html(word)
        content += matches[1] + word + matches[2] + whitespace.join('')
        next
      end

      i+=1
      word = prepare_word(word)

      addBr = word.index('<br />') != nil
      word.gsub!('<br />', '')

      added_prefix = false
      if word[0] == '<' && word.index('>') == nil
        can_print_with_span = false
        html_started = true
        i -= 2
      elsif html_started && word.index('>') == nil
        can_print_with_span = false
        i -= 1
      elsif word.index('>') != nil
        content += matches[1] + word[0...(word.index('>') + 1)]
        added_prefix = true
        word = word[(word.index('>') + 1)..-1]
        can_print_with_span = true
        html_started = false
      end

      if not added_prefix
        content += matches[1]
      end

      if can_print_with_span
        content += "<span id=\"word_#{i}\">#{word}</span>"
        words_raw[i] = word
      else
        content += word
      end

      content += matches[2] + whitespace.join('')

      if addBr
        content += '<br />'
        words_raw[i] += '<br />'
      end
    end
    return content, words_raw

  end
end
