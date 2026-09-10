class Captain::GrammarLanguageGuard
  # Match signatures before individual quoted lines and URLs so their contents
  # are protected as a single, exact fragment.
  PROTECTED_TEXT = %r{(?:^--[\t ]*\r?$.*\z)|(?:^[\t ]*>[^\n]*(?:\n|\z))|(?:https?://[^\s<>]+|www\.[^\s<>]+)}m

  def initialize(original)
    @original = original
  end

  def revisable?
    body(@original).match?(/\p{L}/)
  end

  def rejection_reason(revised)
    return 'empty_response' unless revised.is_a?(String)
    return 'empty_response' if revised.empty?
    return if revised == @original
    return 'protected_text_changed' unless revised.scan(PROTECTED_TEXT) == @original.scan(PROTECTED_TEXT)

    language_rejection_reason(body(revised))
  end

  private

  def body(text)
    text.gsub(PROTECTED_TEXT, ' ')
  end

  def language_rejection_reason(text)
    result = CLD3::NNetLanguageIdentifier.new(0, 10_000).find_language(text)
    return 'uncertain_language' unless result&.reliable?
    return 'non_portuguese' unless result.language.to_s == 'pt'

    nil
  end
end
