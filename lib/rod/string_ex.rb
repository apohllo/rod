class String
  def margin(n=0)
    #d = /\A.*\n\s*(.)/.match( self )[1]
    #d = /\A\s*(.)/.match( self)[1] unless d
    d = ((/\A.*\n\s*(.)/.match(self)) ||
        (/\A\s*(.)/.match(self)))[1]
    return '' unless d
    if n == 0
      gsub(/\n\s*\Z/,'').gsub(/^\s*[#{d}]/, '')
    else
      gsub(/\n\s*\Z/,'').gsub(/^\s*[#{d}]/, ' ' * n)
    end
  end
end
