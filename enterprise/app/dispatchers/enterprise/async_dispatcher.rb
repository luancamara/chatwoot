module Enterprise::AsyncDispatcher
  def listeners
    super + [
      CaptainListener.instance,
      CrmEventListener.instance,
      WhatsappTriageListener.instance
    ]
  end
end
