class Authorization
  class Join < Struct.new(:table, :type, :condition)
    include Authorization::Visitable
  end
end
