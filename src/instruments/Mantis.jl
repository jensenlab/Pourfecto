abstract type Mantis <: Instrument end 

piston_mantis = Piston{ContinuousActuator, MultiRepeater}(
    (0.1u"µL",100u"mL"),
    (0.1u"µL",100u"mL"),
    1
)

mantis_head_mask = trues(1,1) 

mantis_channels = [Channel(100u"mL")]

mantis_head = Head{Mantis}([piston_mantis],mantis_channels, mantis_head_mask)

const mantis_lc3_position =ConstrainedPosition("LC3",Set([Conical,Bottle]),(1,24),true,false,"circle")
const mantis_hv_position =ConstrainedPosition("High Volume Position",Set([Conical,Bottle]),(1,4),true,false,"circle")
const mantis_main=ConstrainedPosition("Main",Set([WP96,WP384,brPCR96]),(1,1),false,true,"rectangle")
mantis_deck = [mantis_hv_position  mantis_main mantis_lc3_position]


configurations["mantis"] = Configuration{Mantis}(mantis_head,mantis_deck,InstrumentSettings())

const mantis_names = Dict(

   WP96 => "PT3-96-Assay.pd.txt",
   WP384 => "PT9-384-Assay.pd.txt",
   brPCR96 => "breakaway_pcr_96.pd.txt"
)


## Mantis Masks 


function Mask(h::Head{Mantis},l::Union{Conical15,Conical50,Bottle1L, Bottle250mL,Bottle500mL}) # mantis can only aspirate into these labware 
    H,L = compute_mask_sizes(h,l)
    asp_positions = compute_positions(h,l)

    function asp(well::Integer,position::Integer,channel::Integer)
        P = asp_positions 
        in_mask_bounds(L,P,H,well,position,channel) || return false 
        wi,wj,pm,pn,ci,cj = linear_to_cartesian(L,P,H,well,position,channel)
        return wi == pm && wj == pn  # well matches position, channel is trivial for this instrument 
    end 

    function disp(well::Integer,position::Integer,channel::Integer)
        return false 
    end 

    
    return Mask(h,l,asp,disp,asp_positions,(0,0)) #asp and disp are equivalent in this case 
end 

function Mask(h::Head{Mantis},l::Union{WP96,WP384,brPCR96}) # mantis can only dispense into these labware 
    H,L = compute_mask_sizes(h,l)
    disp_positions = compute_positions(h,l)

    function disp(well::Integer,position::Integer,channel::Integer)
        P = disp_positions 
        in_mask_bounds(L,P,H,well,position,channel) || return false 
        wi,wj,pm,pn,ci,cj = linear_to_cartesian(L,P,H,well,position,channel)
        return wi == pm && wj == pn  # well matches position, channel is trivial for this instrument 
    end 

    function asp(well::Integer,position::Integer,channel::Integer)
        return false 
    end 

    
    return Mask(h,l,asp,disp,(0,0),disp_positions) #asp and disp are equivalent in this case 
end 



## Mantis Compiling Functions 

function convert_design(design::DataFrame,sources::Vector{<:Labware},targets::Vector{<:Labware},slotting::SlottingDict,config::Configuration{Mantis})

    # helper function that converts the design and slotting scheme into operations for the mantis
    
    all(map(x-> x[1] in deck(config),values(slotting))) || ArgumentError("All deck positions in the SlottingDict must be present on the deck")
    S=length(sources)
    src_idx = vcat([fill(i,length(sources[i])) for i in 1:S]...)
    within_src_index = vcat([1:length(sources[i]) for i in 1:S]...) 
     T=length(targets)
    tgt_idx = vcat([fill(i,length(targets[i])) for i in 1:T]...)
    within_tgt_index = vcat([1:length(targets[i]) for i in 1:T]...) 

    source_names = String[]

    for row in 1:nrow(design)
        lw = sources[src_idx[row]]
        if can_aspirate(lw,slotting[lw][1])
            push!(source_names,"$(JLIMS.name(lw))_$(JLIMS.name.(children(lw))[within_src_index[row]])")
        else
            error("labware $(JLIMS.name(lw)) cannot be used as a source in its slotted location")
        end 
    end 

    for col in 1:ncol(design)
        lw = targets[tgt_idx[col]]
        if can_dispense(lw,slotting[lw][1])
            # do nothing 
        else 
            error("labware $(JLIMS.name(lw)) cannot be used as a target in its slotted location")
        end 
    end 

        
    if length(targets) > 1 
        error("multiple target labware detected. Mantis only supports a single target labware at a time")
    end 

    return design, source_names 
end 

"""

Compiling function for Mantis 
""" 
function write_instrument_files(directory::AbstractString,design::DataFrame,sources::Vector{<:Labware},targets::Vector{<:Labware},config::Configuration{Mantis},slotting::SlottingDict=slotting_greedy(vcat(sources,targets),config);kwargs...) 
        design, source_names= convert_design(design,sources,targets,slotting,config)

        filename=joinpath(directory,basename(directory)*".dl.txt")
        S=nrow(design)
        ### Stopped here 4/29 
        delay_header=vcat(S,repeat([0,""],S))
        outfile=open(filename,"w")
        tgt_plate = targets[1] # convert_design checks that targets is of length 1 
        platefilename=mantis_names[typeof(tgt_plate)]
        R,C = shape(tgt_plate)
        print(outfile,join(["[ Version: 5 ]"],'\t'),"\r\n")
        print(outfile,platefilename,"\r\n")
        print(outfile,join(delay_header,'\t'),"\r\n")
        print(outfile,join([1],'\t'),"\r\n")
        print(outfile,join(delay_header,'\t'),"\r\n")

        for i in 1:S
            vols=collect(design[i,:]) # already in µL as a Real 
            vols=round.(reshape(vols,R,C),digits=1) # mantis rounds volumes to nearest 0.1 µL 
            print(outfile,join([source_names[i],"","Normal"],'\t'),"\r\n")
            print(outfile,join(["Well",1],'\t'),"\r\n")
            for r in 1:R
                print(outfile,join(vols[r,:],'\t'),"\r\n")
            end 
        end 
        close(outfile)
        return nothing 
end 