# Show the README FILE at install time.

puts IO.read(File.join(File.dirname(__FILE__), 'README'))