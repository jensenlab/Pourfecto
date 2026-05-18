




function can_place(l::Labware,d::DeckPosition) 
    for x in collect(labware(d))
      if typeof(l) <: x 
        return true 
      end 
    end 
    return false 
  end


function can_place(l::Labware,d::UnconstrainedPosition)
    return true 
end 

function can_place(l::Labware,d::EmptyPosition)
  return false 
end 


function can_place(labware::Labware,deck::Deck)

  for pos in deck 
    if can_place(labware,pos)
      return true 
    end 
  end
  return false 
end 


function can_aspirate(l::Labware,d::DeckPosition)

  return can_place(l,d) && can_aspirate(d)
end

function can_dispense(l::Labware,d::DeckPosition)
  return can_place(l,d) && can_dispense(d)
  
end


