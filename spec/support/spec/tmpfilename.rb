def tmpfilename(name)
  source = Tempfile.new(name)
  path = source.path
  source.close!
  $global_tempfiles ||= []
  $global_tempfiles << File.expand_path(path)
  path
end
