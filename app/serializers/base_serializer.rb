class BaseSerializer
  def initialize(object)
    @object = object
  end

  def call
    serialize(@object)
  end

  private

  def serialize(object)
    raise NotImplementedError
  end
end
