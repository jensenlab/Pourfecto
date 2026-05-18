
# slotting functions find a layout for labware on a robot with a particular configuration


SlottingDict = Dict{Labware,Tuple{DeckPosition,Int}}

"""
    slottingdict_to_df(slotting::SlottingDict) -> DataFrame

Convert a `SlottingDict` describing labware placement into a `DataFrame`.

The input dictionary is expected to map each labware object `s` to a 2-tuple of the form `(deck_position, slot)`, where:

- `deck_position` is an object whose human-readable identifier is given by
  `name(deck_position)`.
- `slot` is a `String` or `Integer` identifying the slot within that deck
  position.

# Arguments
- `slotting::SlottingDict`: Dictionary of labware placement info.

# Returns
- `DataFrame`: A table with columns `Position`, `Slot`, `LabwareID`, and `Name`.
"""
function slottingdict_to_df(slotting::SlottingDict)
    labware_ids = Integer[]
    labware_names = String[]
    deck_position = String[]
    slot = Union{String,Integer}[]

    for s in keys(slotting)
        push!(labware_ids,location_id(s))
        push!(labware_names,JLIMS.name(s))
        push!(deck_position,slotting[s][1].name)
        push!(slot,slotting[s][2])
    end 
    
    return DataFrame(Position=deck_position,Slot=slot,LabwareID=labware_ids,Name=labware_names)
end 




function slotting_greedy(labware::Vector{<:Labware},config::Configuration)

    for lw in labware 
        can_place(lw,deck(config)) || error("labware type $(typeof(lw)) cannot be placed on a $(name(config)) deck")
    end 

    slotting = SlottingDict()
    open_slots = Set{Tuple{DeckPosition,Int}}()

    for position in deck(config) 
        n_slots = prod(slots(position))
        for i in 1:n_slots 
            push!(open_slots,(position,i))
        end 
    end 

    labware_to_place = Labware[] # only place labware with unique names. Some sources can also be targets, so we need to avoid double counting them 
    duplicate_labware = Labware[]
    for lw in labware 
        if !in(JLIMS.name(lw), JLIMS.name.(labware_to_place))
            push!(labware_to_place,lw)
        else 
            push!(duplicate_labware,lw)
        end
    end 


    not_placed=Labware[]
    for lw in labware_to_place
        placed=false
        for s in open_slots 
            if can_place(lw,s[1])
                slotting[lw]= s 
                delete!(open_slots,s)
                placed=true
                break 
            end 
        end 

        if !placed
            push!(not_placed,lw)
        end 
    end 

    placed_labware = collect(keys(slotting))
    for lw in duplicate_labware
       idx =findfirst(x->name(lw) == name(x),placed_labware)
        slotting[lw] = slotting[placed_labware[idx]] # slot the duplicate labware back into the same spot 
    end 
        

    return slotting
end 



function packing_greedy(pairings::Vector{Tuple{Labware,Labware}},config::Configuration;kwargs...)

    slotting_dicts=SlottingDict[]
    remaining= pairings
    all_labware=union(remaining...)
    while length(remaining) > 0 
        slotting=slotting_greedy(all_labware,config)
        pairings_remaining = filter(x-> any(map(y->!in(y,keys(slotting)),x)),remaining)
        if pairings_remaining == remaining 
            error("unsolvable packing arrangement, $(pairings_remaining)")
        end 
        push!(slotting_dicts,slotting)
        remaining = pairings_remaining
        if length(remaining)==0 
            break 
        end 
        all_labware = union(remaining...)
    end 
    return slotting_dicts 
end 



