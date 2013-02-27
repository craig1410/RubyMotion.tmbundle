REXML::Element.class_eval do
  def <=>(other)
    # Get the display string
    self_name = self[1].text.gsub( /[:\.]/, "" ).gsub( /^(.*?)\s\(.*/, "\\1" )
    other_name = other[1].text.gsub( /[:\.]/, "" ).gsub( /^(.*?)\s\(.*/, "\\1" )

    if self_name < other_name
      -1
    elsif self_name == other_name
      0
    else
      1
    end
  end
end
