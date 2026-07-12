class BaseSerializer
  def initialize(object)
    @object = object
  end

  def call
    serialize(@object)
  end

  private

  def serialize(_object)
    raise NotImplementedError
  end
end
