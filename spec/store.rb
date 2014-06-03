class Store
  def self.flag!
    write('true')
  end

  def self.flag
    File.read('foo') == 'true'
  end

  def self.reset!
    write('')
  end

  def self.write(message)
    f = File.new('foo', "w+")
    f.write(message)
    f.close
  end
end
