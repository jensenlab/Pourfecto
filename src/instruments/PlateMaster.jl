abstract type PlateMaster <: Instrument end 


## Pistons 

pm_piston = Piston{ContinuousActuator,SingleRepeater}(
    (1u"µL",220u"µL"),
    (1u"µL",220u"µL"),
    1
)


## Head 

pm_head_mask = fill(true,1,96)

pm_head = Head{PlateMaster}(
[pm_piston],
fill(Channel(200u"µL"),8,12),
pm_head_mask
)

pm_position(name) = ConstrainedPosition(name,Set([SLASLabware]),(1,1),true,true,"rectangle")

## Deck 

pm_deck = [
    pm_position("Position A1") pm_position("Position A2") ;
    pm_position("Position B1") pm_position("Position B2")
    ]

## Settings 

pm_settings= InstrumentSettings()

## Configuration 

configurations["plate_master"]= Configuration{PlateMaster}(pm_head,pm_deck,pm_settings)


## Masks 

# Add method for position computing with SLAS Labware and platemaster 

# THIS funciton does not handle plates with well spacing denser than a 96 well plate

function compute_positions(h::Head{PlateMaster},l::SLASLabware;kwargs...)
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


function Mask(h::Head{PlateMaster},l::Union{WP96,DeepWP96,brPCR96})  # 96 well plates only 
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

function Mask(h::Head{PlateMaster},l::WP384)  # 384 well plates only 
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



function Mask(h::Head{PlateMaster},l::DeepReservoir)  # single channel SLAS style reservoir only 
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

function Mask(h::Head{PlateMaster},l::DeepWellColumn)  # 96 well plates only 
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

function Mask(h::Head{PlateMaster},l::DeepWellRow)  # 96 well plates only 
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
