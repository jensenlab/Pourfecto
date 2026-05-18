Well = JLIMS.Well
Labware = JLIMS.Labware

#SLAS Standard Plates  
abstract type SLASLabware <:Labware end 
@labware WP96 SLASLabware Well{400} (8,12) "" ""
@labware WP384 SLASLabware Well{100} (16,24) "" ""
@labware DeepWP96 SLASLabware Well{2000} (8,12) "" ""
@labware DeepReservoir SLASLabware Well{150000} (1,1) "" ""
@labware DeepWellColumn SLASLabware Well{20000} (1,12) "" "" 
@labware DeepWellRow SLASLabware Well{20000} (8,1) "" "" 

# PCR Labware 
abstract type PCRLabware <: Labware end 
@labware brPCR96 PCRLabware Well{200} (8,12) "" "" 

# bottles 
abstract type Bottle <:Labware end 
@labware Bottle1L Bottle Well{1000000} (1,1) "" "" 
@labware Bottle500mL Bottle Well{500000} (1,1) "" "" 
@labware Bottle250mL Bottle Well{250000} (1,1) "" "" 

# conical tubes 
abstract type Conical <: Labware end 
@labware Conical50 Conical Well{50000} (1,1) "" "" 
@labware Conical15 Conical Well{15000} (1,1) "" "" 





const plate_alphabet = vcat(["$l" for l in 'A':'Z' ],["A$l" for l in 'A':'Z']) 


function well_to_cartesian(well::AbstractString)
    strs= String.(split(well, r"(?<=\d)(?=\D)|(?<=\D)(?=\d)"))

    if  length(strs) != 2
        throw(ArgumentError("well name: $well not in expected format, eg. A1, H12"))
    end 
    letter_idx = findfirst(x-> x == strs[1], plate_alphabet) 
    if isnothing(letter_idx) 
        throw(DomainError("Well row not within supplied plate row alphabet"))
    end 
    number_idx = parse(Int64,strs[2])
    return CartesianIndex(letter_idx,number_idx)
end 


function cartesian_to_well(idx::CartesianIndex)
    return "$(plate_alphabet[idx[1]])$(idx[2])"
end 


function generate(T::Type{<:Labware},name::AbstractString)
    lw = T(0,String(name))
    sh = JLIMS.shape(lw)

    ch_type = JLIMS.childtype(lw) 
    for idx in CartesianIndices(sh)
            w_name = cartesian_to_well(idx)
            children(lw)[idx] = ch_type(0,w_name) 
    end 
    return lw 
end 
generate(T::Type{<:Labware}) = generate(T,string(uuid4())) 



function stocks(lw::JLIMS.Labware)
    st = Stock[]
    for ch in JLIMS.children(lw) 
        push!(st,JLIMS.stock(ch))
    end 
    return st 
end 

function stocks(lws::Vector{<:JLIMS.Labware})
    return vcat(stocks.(lws)...)
end 


function length(lw::JLIMS.Labware)
    return length(JLIMS.children(lw))
end

"""
    add_stock!(lw::JLIMS.Labware, stock::JLIMS.Stock, row::Integer, col::Integer) -> JLIMS.Labware

Deposit `stock` into the well at `(row, col)` in `lw`.

This is a convenience wrapper around `JLIMS.deposit!` for manually filling labware.
If the selected well is not empty, a warning is emitted and the function still
attempts to deposit the stock.

# Arguments
- `lw::JLIMS.Labware`: Labware object to modify.
- `stock::JLIMS.Stock`: Stock to deposit.
- `row::Integer`: Row index of the target well.
- `col::Integer`: Column index of the target well.

# Returns
- `JLIMS.Labware`: The modified labware object `lw`.
"""
function add_stock!(lw::JLIMS.Labware,stock::JLIMS.Stock,row::Integer,col::Integer)
    well = JLIMS.chlidren(lw)[row,col]
    if JLIMS.stock(well) != Empty() 
        @warn("selected well is not empty, attempting to add the stock to the well")
    end 
    deposit!(well,stock,0)
    return lw 
end 




