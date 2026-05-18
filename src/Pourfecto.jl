module Pourfecto

using Unitful, JLIMS , AbstractTrees, DataFrames , JuMP , Gurobi , JSON, Plots, Random, CSV , Dates, TextWrap

import InteractiveUtils: subtypes 
import JSONTables: objecttable, jsontable 
import StructUtils: lowerkey 
import UUIDs: uuid4 
import Plots: plot 
import Base: length



include("types.jl")
include("instruments/utils.jl")
include("exceptions.jl")
include("default_labware.jl")
include("mask_utils.jl")
include("stock_utils.jl")
include("dataframe_interface.jl")

include("pourfecto_algorithms/helpers.jl")
include("pourfecto_algorithms/objectives.jl")
include("pourfecto_algorithms/parameter_defaults.jl")
include("pourfecto_algorithms/algorithms.jl")



function all_concrete_subtypes(T::Type)
    # If the type is concrete, it has no further subtypes to check, so return it in a list.
    isconcretetype(T) && return [T]

    # Initialize a list to store the results
    out = Type[]

    # Get immediate subtypes and recursively call the function on each
    for K in subtypes(T)
        append!(out, all_concrete_subtypes(K))
    end
    
    return out
end

lw_types = all_concrete_subtypes(Labware)



"""
    labwares

By default, Pourfecto provides an assortment of pre-defined labware. Use `keys(labwares)` to see available instruments

"""
const labwares = Dict(string.(nameof.(lw_types)) .=> lw_types)



"""
    generate(T::AbstractString, name::AbstractString)

Generate a labware instance from a registered labware code.

`T` is a short identifier (index code) used to look up a labware template in the
global `labwares` registry. If the code is present, this method delegates to the
underlying generator:

`generate(labwares[T], name)`

# Examples
```julia
lw = generate("WP96", "plate_1")   # code must exist in keys(labwares)
```

"""
function generate(T::AbstractString,name::AbstractString) 
    if !in(T, keys(labwares)) 
        error("labware code $T not found in available labware. avialable options include:")
    end 
    
    return generate(labwares[T],name) # strings allow us to only accept certain labware index codes 
end 


"""
    configurations

By default, Pourfecto provides an assortment of pre-defined instruments. Use `keys(configurations)` to see available instruments

"""
const configurations= Dict{String,Configuration}()


include("./compiler/adverbs_verbs.jl")
include("./compiler/slotting.jl")
include("plotting/plotting.jl")
include("./compiler/helpers.jl")
include("./instruments/SingleChannel.jl")
include("./instruments/EightChannel.jl")
include("./instruments/PlateMaster.jl")
include("./instruments/Cobra.jl")
include("./instruments/Nimbus.jl")
include("./instruments/Mantis.jl")
include("./instruments/Tempest.jl")
include("json_interface.jl")
include("./compiler/compile.jl")




"""
        pourfecto(directory::AbstractString,
                source_labware::Vector{<:JLIMS.Labware},
                target_labware::Vector{<:JLIMS.Labware},
                configs::Union{Vector{<:AbstractString},Vector{<:Configuration}};
                kwargs...)

Run the Pourfecto algorithm in **planning and scheduling** mode and automatically compile the resulting `Pourcast`(@ref) in `directory`. 

If the Pourcast fails a `solution_quality` check, `pourfecto` will produce an error message while saving the `Pourcast` and quality report to the directory
## Arguments 
* `directory`: The output directory (will be made if it doesn't already exist)
* `source_labware`: The JLIMS.Labware objects containing source stocks that pourfecto can use to create the targets 
* `target_labware`: The JLIMS.Labware objects containing target stocks pourfecto is trying to create using the sources
* `configs` : The the Configuration objects **or** String identifiers for instrument configurations pourfecto can use to schedule the planned liquid transfers. 

## Keyword Arguments 
$(_pourfecto_kw_doc_())
"""
function pourfecto(directory::AbstractString,source_labware::Vector{<:JLIMS.Labware},target_labware::Vector{<:JLIMS.Labware},configs::Union{Vector{<:AbstractString},Vector{<:Configuration}};kwargs...)
    pc = pourfecto(source_labware,target_labware,configs;kwargs...)
    if !isdir(directory) 
        mkdir(directory)
    end 
    qual = solution_quality(pc) 
    if any(qual)
        report = solution_quality_report(pc)
        CSV.write(joinpath(directory,"solution_quality_report.csv"),report)
        JSON.json(joinpath(directory,"pourcast.json"),pourcast_to_json(pc))
        message = "Pourcast failed quality control. Aborting compile and reporting errors to $(directory)"
        midline = repeat("-",length(message))
        error("$message \n$midline \n$(report)")
    else
        compile(directory,pc;kwargs...)
    end 
    return pc 
end 



export PriorityDict
export Configuration, Head, Deck


export configurations, labwares, objectives # constants 

export generate

export reagent_to_string, string_to_reagent # string interface for reagents 

export df_to_stock, stock_to_df, df_to_labware, labware_to_df # dataframe interface 

export pourfecto # main pourfecto algorithm 

export Pourcast, flows, transfers , slacks , planned_stocks , target_stocks, source_stocks, target_labware, source_labware, model_solution,scheduling_objective_value,configs ,transfers_by_config , params # pourcast functions 

export json_to_pourcast, pourcast_to_json # json interface 

export plot , plot_flows # visualization 

export compile # compiler 


end # module Pourfecto
