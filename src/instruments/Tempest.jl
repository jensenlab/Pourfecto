abstract type Tempest <: Instrument end 

piston_tempest = Piston{ContinuousActuator, MultiRepeater}(
    (0.1u"µL",100u"mL"),
    (0.1u"µL",100u"mL"),
    1
)
tempest_head_mask = falses(8,8) 
for i in 1:8
    tempest_head_mask[i,i] = true 
end 



tempest_head = Head{Tempest}(fill(piston_tempest,8),fill(Channel(100u"mL"),8), tempest_head_mask)

const tempest_input =ConstrainedPosition("Tempest Input Slots",Set([Conical,Bottle]),(1,6),true,false,"circle")
const tempest_main=ConstrainedPosition("Main Tempest Position",Set([WP96,WP384]),(1,1),false,true,"rectangle")
tempest_deck = vcat(tempest_input,tempest_main)


configurations["tempest"] = Configuration{Tempest}(tempest_head,tempest_deck,InstrumentSettings())


const tempest_names=Dict(
    WP96=>"PT3-96-Assay.pd.txt",
    WP384=>"PT9-384-Assay.pd.txt"
)


## Tempest Masks 

function compute_positions(h::Head{Tempest},l::Union{Conical,Bottle};kwargs...)
    return (1,1)
end 


function Mask(h::Head{Tempest},l::Union{Conical,Bottle}) # tempest can only aspirate from these labware 
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

    
    return Mask(h,l,asp,disp,asp_positions,(0,0))
end 

function Mask(h::Head{Tempest},l::WP96) # tempest can only dispense into these labware 
    H,L = compute_mask_sizes(h,l)
    disp_positions=compute_positions(h,l)
    function disp(well::Integer,position::Integer,channel::Integer)
        P = disp_positions
        in_mask_bounds(L,P,H,well,position,channel) || return false 
        wi,wj,pm,pn,ci,cj = linear_to_cartesian(L,P,H,well,position,channel)
        return wi == ci + pm -1 && wj == pn +cj -1  # channel row matches well row, and well column matches position column 
    end 
    function asp(well::Integer,position::Integer,channel::Integer)
        return false 
    end 
 
    return Mask(h,l,asp,disp,(0,0),disp_positions) 
end 

function Mask(h::Head{Tempest},l::WP384)  # 384 well plates only 
    H,L = compute_mask_sizes(h,l)
    disp_positions = compute_positions(h,l;v_spacing=2,h_spacing=2)
    function disp(well::Integer,position::Integer,channel::Integer)
        P = disp_positions  # channels are spaced to hit every other well row 
        in_mask_bounds(L,P,H,well,position,channel) || return false 
        wi,wj,pm,pn,ci,cj = linear_to_cartesian(L,P,H,well,position,channel)
        return wi == 2*(ci-1) + pm && wj == pn + 2*(cj-1) # well row is offset by the channel and position, well column matches the position 
    end 
    function asp(well::Integer,position::Integer,channel::Integer)
        return false 
    end 
 
    return Mask(h,l,asp,disp,(0,0),disp_positions) 
end 

## Compiling Functions 


function convert_design(design::DataFrame,sources::Vector{<:Labware},targets::Vector{<:Labware},slotting::SlottingDict,config::Configuration{Tempest})

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
        designs = DataFrame[]
        for i in eachindex(targets)
            idxs = findall(x-> x==i ,src_idx)
            lw_design = design[:,idxs]
            push!(designs,lw_design)
        end 
        return designs, source_names 
    else


        return design, source_names 
    end 
end 


function write_tempest_dl(filename::String,design::DataFrame,target::Labware,source_names::Vector{String})
    n_stocks=nrow(design)
    outfile=open(filename,"w")
    platefilename=tempest_names[typeof(target)]
    print(outfile,join(["Version            :", 6],'\t'),"\r\n")
    print(outfile,join(["Plate type name    :", platefilename],'\t'),"\r\n")
    print(outfile,join(["Priority Delays    :", 0],'\t'),"\r\n")
    R,C=JLIMS.shape(target)

    for i in 1:n_stocks 
        vols=Vector(design[i,:])
        vols=reshape(vols,R,C)
        print(outfile,join(["Reagent Name    :", source_names[i]],'\t'),"\r\n")
        print(outfile,join(["Barcode            :"],'\t'),"\r\n")
        print(outfile,join(["Priority           :", 1],'\t'),"\r\n")
        for r in 1:R
            print(outfile,join(vols[r,:],'\t'),"\r\n")
        end 
    end 
    close(outfile)
end
    
function write_instrument_files(directory::AbstractString,design::DataFrame,sources::Vector{<:Labware},targets::Vector{<:Labware},config::Configuration{Tempest},slotting::SlottingDict=slotting_greedy(vcat(sources,targets),config);kwargs...) 

    protocol_name = basename(directory)
    dispenses, source_names =convert_design(design,sources,targets,slotting,config)
    if ~isdir(directory)
        mkdir(directory)
    end


    N = 1 
    if dispenses isa Vector{DataFrame}
        N = length(dispenses) 
    end 
    if N == 1  # single dispense file 
        filename=joinpath(directory,protocol_name*".dl.txt")
        write_tempest_dl(filename,dispenses,targets[1],source_names)
    else  # multidispense 

        allequal(typeof.(targets)) || error("all targets must be the same plate type for a tempest multidispense protocol")

        protocol_names = [protocol_name*i for i in 1:N]
        for i in 1:N 
            filename=joinpath(directory,protocol_names[i]*".dl.txt")
            write_tempest_dl(filename,dispenses[i],targets[i],source_names)
        end 
        mdlbasename=protocol_name*".mdl.txt"
        outpath=joinpath(directory,mdlbasename)
        outfile=open(outpath,"w")
        print(outfile,join(["LP:$(tempest_names[targets[1]]).pd.txt"],'\t'),"\r\n") # we previously check that all destinations are the same type, so we can safely take the first one
        for i in 1:n
            print(outfile,join(["P:$i","TP:1","DL:$(protocol_names[i])"],'\t'),"\r\n")
        end
        close(outfile)
    end
    
    #delay_header=vcat(n_stocks,repeat([0,""],n_stocks))

    return nothing 
end

