module Enterprise::AsyncDispatcher
  def listeners
    super + [
      CaptainListener.instance,
      CrmEventListener.instance
    ]
  end
end
