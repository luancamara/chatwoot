module Enterprise::MessageFinder
  def conversation_messages
    super.includes(call: [:contact, { inbox: :channel }])
  end

  # Messages are ordered by created_at but paginated with an id cursor, which
  # assumes the two agree. A backfilled ad origin note breaks that assumption:
  # it carries an old created_at and a brand new id, so an `id <` cursor skips
  # past it and the note is never reachable by scrolling up.
  #
  # Paginating on (created_at, id) keeps the cursor aligned with the sort.
  def messages_before(before_id)
    cursor = conversation_messages.find_by(id: before_id)
    return super if cursor.blank?

    messages.reorder('created_at desc, id desc')
            .where('(messages.created_at, messages.id) < (?, ?)', cursor.created_at, cursor.id)
            .limit(20)
            .reverse
  end
end
