class ErrorSerializer < BaseSerializer
  private

  def serialize(error)
    {
      error: {
        code: error[:code],
        message: error[:message]
      }
    }
  end
end
