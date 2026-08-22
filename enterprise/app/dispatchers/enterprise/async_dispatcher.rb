module Enterprise::AsyncDispatcher
  def listeners
      super + [
        CaptainListener.instance,
        CrmEventListener.instance,
        ConversationRiskMonitorListener.instance,
        Captain::ReportingEventListener.instance
      ]
  end
end
