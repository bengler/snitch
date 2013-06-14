module Petroglyphy

  def to_petroglyph
    class_name ||= self.class.name.downcase
    @petroglyph_template ||= "api/v1/views/#{class_name}.pg"
    @petroglyph_engine ||= Petroglyph::Engine.new(File.read(@petroglyph_template))
    @petroglyph_engine.to_hash({class_name.to_sym => self}, @petroglyph_template)
  end

end
