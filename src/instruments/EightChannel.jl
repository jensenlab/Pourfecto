abstract type EightChannel <: Instrument end 

## Pistons 
piston_p1000  = Piston{ContinuousActuator,SingleRepeater}(
    (200u"µL",1000u"µL"),
    (200u"µL",1000u"µL"),
    1
)

piston_p100 = piston_p1000  = Piston{ContinuousActuator,SingleRepeater}(
    (10u"µL",100u"µL"),
    (10u"µL",100u"µL"),
    1
)

piston_p10  = Piston{ContinuousActuator,SingleRepeater}(
    (1u"µL",10u"µL"),
    (1u"µL",10u"µL"),
    1
)

piston_eight_channel = Piston{ContinuousActuator,SingleRepeater}(
    (1u"µL",1000u"µL"),
    (1u"µL",1000u"µL"),
    1
)

eight_channel_pistons = [piston_eight_channel,piston_p1000,piston_p100,piston_p10]


## Heads 

eight_channel_head_mask = trues(1,8) 

eight_channel_types = [Channel(1200u"µL"),Channel(1200u"µL"),Channel(220u"µL"),Channel(25u"µL")]

eight_channel_channels = AbstractArray{Channel}[]
for typ in eight_channel_types 
    push!(eight_channel_channels,fill(typ,8,1)) # vertical orientation
    push!(eight_channel_channels,fill(typ,1,8)) # horizontal orientation 
end 


eight_channel_heads = Head[] 

for h in eachindex(eight_channel_channels)
    push!(eight_channel_heads,Head{EightChannel}([repeat(eight_channel_pistons,inner=2)[h]],eight_channel_channels[h],eight_channel_head_mask))
end 


## Decks 

eight_channel_deck = [
    ConstrainedPosition("benchtop",Set([SLASLabware]),(2,1),true,true,"rectangle") # Only two positions allowed to force new protocols for each pair of labware when slotting
    ]


## Settings 


eight_channel_settings = InstrumentSettings()

## Configurations 

eight_channel_names =[
    "eight_channel_vertical",
    "eight_channel_horizontal",
    "p1000_8_vertical",
    "p1000_8_horizontal",
    "p100_8_vertical",
    "p100_8_horizontal",
    "p10_8_vertical",
    "p10_8_horizontal"
]

for h in eachindex(eight_channel_heads)
    configurations[eight_channel_names[h]]= Configuration{EightChannel}(eight_channel_heads[h],eight_channel_deck,eight_channel_settings)
end 


## Masks 

# Add method for position computing with SLAS Labware and eight channel pipettes

# THIS funciton does not handle plates with well spacing denser than a 96 well plate

function compute_positions(h::Head{EightChannel},l::SLASLabware;kwargs...)
     H,L = compute_mask_sizes(h,l) 
     r = H[1]
     c = H[2]
     if H[1] > L[1] && H[1] <= 8 # based on typical spacing 
       r = L[1]
     end 
     if H[2] > L[2] && H[2] <= 12 #based on typical spacing 
        c = L[2]  
     end 
     return compute_positions((r,c),L;kwargs...)
end 





function Mask(h::Head{EightChannel},l::Union{WP96,DeepWP96,brPCR96})  # 96 well plates only 
    H,L = compute_mask_sizes(h,l)
    asp_positions=compute_positions(h,l)
    function asp(well::Integer,position::Integer,channel::Integer)
        P = asp_positions
        in_mask_bounds(L,P,H,well,position,channel) || return false 
        wi,wj,pm,pn,ci,cj = linear_to_cartesian(L,P,H,well,position,channel)
        return wi == ci + pm -1 && wj == pn +cj -1  # channel row matches well row, and well column matches position column 
    end 

    disp = asp # no difference in aspirate or dispense masks 
    disp_positions= asp_positions
    return Mask(h,l,asp,disp,asp_positions,disp_positions) 
end 


# We must make an change to the function for using 384 well plates 

function Mask(h::Head{EightChannel},l::WP384)  # 384 well plates only 
    H,L = compute_mask_sizes(h,l)
    asp_positions = compute_positions(h,l;v_spacing=2,h_spacing=2)
    function asp(well::Integer,position::Integer,channel::Integer)
        P = asp_positions  # channels are spaced to hit every other well row 
        in_mask_bounds(L,P,H,well,position,channel) || return false 
        wi,wj,pm,pn,ci,cj = linear_to_cartesian(L,P,H,well,position,channel)
        return wi == 2*(ci-1) + pm && wj == pn + 2*(cj-1) # well row is offset by the channel and position, well column matches the postion 
    end 

    disp = asp # no difference in aspirate or dispense masks
    disp_positions= asp_positions 
    return Mask(h,l,asp,disp,asp_positions,disp_positions) 
end 



function Mask(h::Head{EightChannel},l::DeepReservoir)  # single channel SLAS style reservoir only 
    H,L = compute_mask_sizes(h,l)
    asp_positions = compute_positions(h,l)
    function asp(well::Integer,position::Integer,channel::Integer)
        P = asp_positions
        in_mask_bounds(L,P,H,well,position,channel) || return false 
        wi,wj,pm,pn,ci,cj = linear_to_cartesian(L,P,H,well,position,channel)
        return true  # well row is offset by the channel and position, well column matches the postion 
    end 

    disp = asp # no difference in aspirate or dispense masks 
    disp_positions = asp_positions
    return Mask(h,l,asp,disp,asp_positions,disp_positions) 
end 

function Mask(h::Head{EightChannel},l::DeepWellColumn)  # 96 well plates only 
    H,L = compute_mask_sizes(h,l)
    asp_positions = compute_positions(h,l)
    function asp(well::Integer,position::Integer,channel::Integer)
        P = asp_positions
        in_mask_bounds(L,P,H,well,position,channel) || return false 
        wi,wj,pm,pn,ci,cj = linear_to_cartesian(L,P,H,well,position,channel)
        return wi ==  pm  && wj == cj + pn - 1  # well column is offset by the channel and position, well row matches the postion 
    end 

    disp = asp # no difference in aspirate or dispense masks 
    disp_positions = asp_positions
    return Mask(h,l,asp,disp,asp_positions,disp_positions)  
end 

function Mask(h::Head{EightChannel},l::DeepWellRow)  # 96 well plates only 
    H,L = compute_mask_sizes(h,l)
    asp_positions = compute_positions(h,l)
    function asp(well::Integer,position::Integer,channel::Integer)
        P = asp_positions
        in_mask_bounds(L,P,H,well,position,channel) || return false 
        wi,wj,pm,pn,ci,cj = linear_to_cartesian(L,P,H,well,position,channel)
        return wi == ci + pm -1  && wj ==  pn   # well row is offset by the channel and position, well column matches the postion 
    end 

    disp = asp # no difference in aspirate or dispense masks 
    disp_positions = asp_positions
    return Mask(h,l,asp,disp,asp_positions,disp_positions)  
end 





