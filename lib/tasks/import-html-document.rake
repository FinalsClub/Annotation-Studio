require 'rake'

namespace :file_import do
  desc "import files as documents"
  # rake file_import:html_document\["../shkspr-annotations/A Midsummer Night  's Dream 16.html"\]
  task :html_document, [:filepath] => :environment do |t, args|
    file = File.join(Rails.root, args.filepath)

    @document = Document.new
    @document.title = File.basename(file)
    @document.author = ""
    # TODO: Change to specific user
    @document.user_id = 1
    # TODO: What state should it be?
    @document.state = "pending"
    @document.text = File.read(file)
    @document.processed_at = DateTime.now
    @document.save!
  end
end
