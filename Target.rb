class Target
  attr_accessor :name, :extension, :description, :codes, :params, :heap

  def initialize(name, extension, description, codes, params, do_lambda, exec_lambda)
    @name = name
    @extension = extension
    @description = description
    @codes = codes
    @params = params
    @do_lambda = do_lambda
    @exec_lambda = exec_lambda
    @heap = []
  end

  def do?()
    @do_lambda.call(self)
  end

  def exec()
    @exec_lambda.call(self)
  end

  def to_s
    @name
  end
end
