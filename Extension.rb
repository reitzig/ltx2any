class Extension
  attr_accessor :name, :description, :codes, :params
  
  def initialize(name, description, codes, params, do_lambda, exec_lambda)
    @name = name
    @description = description
    @codes = codes
    @params = params
    @do_lambda = do_lambda
    @exec_lambda = exec_lambda 
  end
  
  def do?()
    @do_lambda.call
  end

  def exec()
    @exec_lambda.call
  end

  def to_s
    @name
  end
end
