module Helpers
	HTML_DIR = File.join(
		File.dirname(__FILE__),
		'..', 'html'
	)

	def html(name)
		File.read(File.join(HTML_DIR, "#{name}.html"))
	end
end
