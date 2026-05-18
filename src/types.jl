

"""
  abstract type Actuator end 

Represents the mechnaism used to move liquid in a Piston. 

"""
abstract type Actuator end 

"""
  abstract type ContinuousActuator <: Actuator end 

Represents a continuous flow mechanism for liquid handler Piston types 

See Also: [`Actuator`](@ref)
"""
abstract type ContinuousActuator <: Actuator end 

"""
  abstract type DiscreteActuator <: Actuator end 

  a discrete shot mechanism for liquid handler Piston types 

See Also: [`Actuator`](@ref)
"""
abstract type DiscreteActuator <: Actuator end 



"""
  abstract type RepeaterStyle  end 

Represents how a liquid handler handles repeated aspirations and dispenses. For example, a single channel pipette must dispense its entire aspirate in one shot, while other liquid handlers can fire repeated shots.  


"""
abstract type RepeaterStyle  end


"""
  abstract type SingleRepeater <: RepeaterStyle end 

SingleRepeater styles require that when a piston dispenses, it dispenses all of its volume in a single shot

See Also: [`RepeaterStyle`](@ref)

"""
abstract type SingleRepeater <: RepeaterStyle end 

"""
  abstract type MultiRepeater <: RepeaterStyle end 

MultiRepeater styles allow the piston to dispense a single aspiration in multiple shots 

See Also: [`RepeaterStyle`](@ref)
"""
abstract type MultiRepeater <: RepeaterStyle end 


# Customize these as the library grows
const ACTUATOR_TYPES = Dict{String,DataType}(
    "ContinuousActuator" => ContinuousActuator,
    "DiscreteActuator"   => DiscreteActuator,
)

const REPEATER_TYPES = Dict{String,DataType}(
    "SingleRepeater" => SingleRepeater,
    "MultiRepeater"  => MultiRepeater,
)


"""
  struct Piston{A <: Actuator, R<: RepeaterStyle}  
      minAsp::Unitful.Volume 
      maxAsp::Unitful.Volume 
      minDisp::Unitful.Volume
      maxDisp::Unitful.Volume
      deadPad::Real
  end

Pistons control how liquid moves in and out of the Head of a Liquid handler. They are parameterized by an [`Actuator`](@ref) and a [`RepeaterSytle`]. The fields of the piston define their maximum and minimum aspirating and dispensing volumes. The `deadPad` field is a multiplicative factor to account for error and miscalibration in the piston. 

"""
struct Piston{A <: Actuator, R<: RepeaterStyle}  
    asp::Tuple{Unitful.Volume,Unitful.Volume}
    disp::Tuple{Unitful.Volume,Unitful.Volume}
    deadPad::Real
end



function repeater_style(p::Piston{A,R})  where {A,R}
  return R 
end 

function actuator_type(p::Piston{A,R}) where {A,R}
  return A 
end 









"""
struct Channel
    capacity::Unitful.Volume 
end 

A `Channel` defines the liquid handler's capacity for carrying liquid. This can be set independent of the piston. 

"""
struct Channel
    capacity::Unitful.Volume 
    function Channel(cap) 
        cap > 0u"µL" ? new(cap) : error("channel capacity must be non-negative")
    end 
end 



"""
   abstract type Instrument end 

Abstract Supertype to define new instruments. Each new class of instrument should define a new abstract type 

For example, 
```jldoctest 
julia>  abstract type NewInstrument <: Instrument end 
```
We refer to instances of liquid handlers as a [`Configuration`](@ref) which are parameterized by the abstract instrument type
```jldoctest
julia> Configuration{SingleChannel} 
```

See Also [`Configuration`](@ref)
"""
 abstract type Instrument end 




"""
  struct Head{I<:Instrument} 
    pistons::AbstractArray{<:Piston}
    channels::AbstractArray{Channel}
    mask::BitMatrix
  end 

An instance of a head for a instrument `I`. Heads contains `pistons` that indpendently control aspiration and dispensation volumes and `channels` that access wells. Pistons and channels are usually arranged as an array. The head definition also includes a `mask` that defines which pistons are connected to which channels. 

```jldoctest

julia> abstract type ExSingleChannel <: Instrument end 

julia> piston = Piston{ContinuousActuator,SingleRepeater}((20u"µL",200u"µL"),(20u"µL",200u"µL"),1) 

julia> head = Head{ExSingleChannel}(
  [piston],
  [Channel(220u"µL")],
  trues(1,1)
)
```

See Also [`Piston`](@ref), [`Channel`](@ref)

"""
struct Head{I<:Instrument} 
    pistons::AbstractArray{<:Piston}
    channels::AbstractArray{Channel}
    mask::BitMatrix
    function Head{I}(pistons,channels,mask) where I<: Instrument
      p = length(pistons)
      c = length(channels)
      size(mask) == (p,c) ? new{I}(pistons,channels,mask) : error("mask size $(size(mask)) must match the number of pistons ($p) and channels ($c)")
    end 
end 

pistons(h::Head) = h.pistons 
channels(h::Head) = h.channels 



function generate_mask(h::Head)

  function H(p::Integer,c::Integer)
    p in eachindex(pistons(h))|| return false 
    c in eachindex(channels(h))|| return false 
    return h.mask[p,c]
  end 
  return H 
end 


"""
  abstract type DeckPosition end 

Supertype for deck position definitons

"""
abstract type DeckPosition end 



"""
  struct EmptyPosition <: DeckPosition 
    name::String
  end 

Represents an empty or inaccessible position on the deck. 

"""
struct EmptyPosition <: DeckPosition 
  name::String
end 

"""
  struct UnconstrainedPosition <: DeckPosition 
    name::String
  end 

Represents a position that can hold any number of any labware

"""
struct UnconstrainedPosition <:DeckPosition 
  name::String
  aspirate::Bool
  dispense::Bool
  plotting_shape::String
end 



"""
  struct ConstrainedPosition <: DeckPosition 
    name::String 
    labware::Set{Type{<:Labware}}
    slots::Tuple{Int,Int}
    aspirate::Bool
    dispense::Bool
    plotting_shape::String
  end 

Represents a position that can hold a set of specified `JLIMS.Labware`` Types. Constrained positions have specified slots for allowable labware 

"""
struct ConstrainedPosition <: DeckPosition 
  name::String 
  labware::Set{Type{<:JLIMS.Labware}}
  slots::Tuple{Int,Int}
  aspirate::Bool
  dispense::Bool
  plotting_shape::String
end 


slots(x::ConstrainedPosition)= x.slots 
slots(::UnconstrainedPosition) = (4,6) # 24 at a time seemed like I reasonable cap when I wrote this. 
slots(::EmptyPosition) = (0,0) 
labware(x::ConstrainedPosition) = x.labware
labware(::UnconstrainedPosition) = Set([JLIMS.Labware])
labware(::EmptyPosition) = Set{Type{<:Labware}}()

can_aspirate(::EmptyPosition) = false 
can_aspirate(x::DeckPosition) = x.aspirate
can_dispense(::EmptyPosition) = false
can_dispense(x::DeckPosition) = x.dispense

"""
  Deck = AbstractArray{<:DeckPosition}

Alias for an array of `DeckPosition` objects 

"""
Deck = AbstractArray{<:DeckPosition}







"""
  InstrumentSettings = Dict{String,Any}

Alias for a Dict with settings for a particular instrument 
"""
InstrumentSettings = Dict{String,Any}


"""
    struct Configuration{I<:Instrument}
      head::Head{I}
      deck::Deck
      settings::InstrumentSettings
    end 

An instance of a liquid handler instrument with definitions for the head, deck, and other settings

See Also: [`Head`](@ref), [`Deck`](@ref), [`InstrumentSettings`](@ref)

"""
struct Configuration{I<:Instrument}
    head::Head{I}
    deck::Deck
    settings::InstrumentSettings
end 

head(C::Configuration) = C.head 
deck(C::Configuration) = C.deck 
settings(C::Configuration) = C.settings 

get_config_type(::Configuration{I}) where I = I 


"""
    struct Mask 
        head::Head
        labware::Labware
        asp::Function 
        disp::Function
        asp_positions::Tuple{Integer,Integer}
        disp_positions::Tuple{Integer,Integer}
    end 

Contains all of the mask related objects used to compute flows. We include separate entries for the aspirate and dispnese mask functions becuase they may be different for some liquid handlers. 


"""
struct Mask 
  head::Head
  labware::Labware
  asp::Function 
  disp::Function
  asp_positions::Tuple{Integer,Integer}
  disp_positions::Tuple{Integer,Integer}
end 

head(M::Mask) = M.head 
labware(M::Mask) = M.labware 
asp(M::Mask) = M.asp 
disp(M::Mask) = M.disp 
asp_positions(M::Mask) = M.asp_positions
disp_positions(M::Mask) = M.disp_positions 


Mask(h::Head,l::Labware)= Mask(h,l,(x,y,z)->false,(x,y,z)->false,(0,0),(0,0)) # by default, masks are trivial --- they do not allow any interface between the head and labware. Each mask must be dfefined in the instrument definition. 



abstract type FlowNode end 

struct AspNode <: FlowNode 
  mask::Mask 
  configuration::Configuration
  piston::Integer
  position::Integer 
  AspNode(mask,configuration,piston,position) = position in 1:prod(asp_positions(mask)) && piston in 1:length(pistons(head(mask))) ? new(mask,configuration,piston,position) : error("selected position/piston is not valid")
end 

struct DispNode <: FlowNode 
  mask::Mask
  configuration::Configuration
  piston::Integer
  position::Integer 
  DispNode(mask,configuration,piston,position) = position in 1:prod(disp_positions(mask)) && piston in 1:length(pistons(head(mask))) ? new(mask,configuration, piston,position) : error("selected position/piston is not a valid ")
end 





"""
    PriorityDict = Dict{String,UInt64}

Dictionary type alias mapping reagent identifiers to a priority
rank used during the Pourfecto planning stage.

Lower values represent higher priority (e.g., `1` is higher priority than `2`).
A common convention is to use `typemax(UInt64)` to indicate “lowest priority” or
“effectively no priority preference”.

# Examples
```jldoctest
julia> PriorityDict(
           "sodium"    => 1,
           "potassium" => 1,
           "ethanol"   => 2,
           "water"     => typemax(UInt64),
       )
Dict{String, UInt64} with 4 entries:
  "water"     => 18446744073709551615
  "ethanol"   => 2
  "sodium"    => 1
  "potassium" => 1
"""
const PriorityDict = Dict{String,UInt64}


"""
    ParameterDict = Dict{Symbol,Any}

An Alias for Dict{Symbol,Any} that can be used to store keyword arguments for Pourfecto
"""
ParameterDict = Dict{Symbol,Any}




"""
    Pourcast

A result container for the `pourfecto` workflow. `Pourcast` bundles
the relevant source/target stocks and labware, the instrument configuration set used for scheduling, the parameters supplied to `pourfecto`, and the resulting model solution and objective value.

"""
struct Pourcast
  source_stocks::Vector{<:JLIMS.Stock}
  target_stocks::Vector{<:JLIMS.Stock}
  source_labware::Vector{<:JLIMS.Labware}
  target_labware::Vector{<:JLIMS.Labware}
  configs::Vector{<:Configuration}
  params::ParameterDict
  model_solution::Dict{Symbol,Any}
  scheduling_objective_value::Real
end


"""
    source_stocks(p::Pourcast) -> Vector{<:JLIMS.Stock}

Return the source (input) stocks associated with `p`.
"""
source_stocks(p::Pourcast) = p.source_stocks

"""
    target_stocks(p::Pourcast) -> Vector{<:JLIMS.Stock}

Return the target (output) stocks associated with `p`.
"""
target_stocks(p::Pourcast) =p.target_stocks 

"""
    source_labware(p::Pourcast) -> Vector{<:JLIMS.Labware}

Return the source labware associated with `p`. The labware also provide the source stocks. They are stored separately because not all pourcasts have associated labware.
"""
source_labware(p::Pourcast) = p.source_labware

"""
    target_labware(p::Pourcast) -> Vector{<:JLIMS.Labware}

Return the target labware associated with `p`. The labware also provide the target stocks. They are stored separately because not all pourcasts have associated labware.
"""
target_labware(p::Pourcast) = p.target_labware
"""
    configs(p::Pourcast) -> Vector{<:Configuration}

Return the instrument configurations used by pourfecto to schedule the liquid handling operations
"""
configs(p::Pourcast) = p.configs

"""
    params(p::Pourcast) -> ParameterDict

Return the parameter dictionary used to store all metadata from each pourfecto run. 
"""
params(p::Pourcast) = p.params 
"""
    model_solution(p::Pourcast) -> Dict{Symbol,Any}

Return the raw JuMP model output from the pourfecto algorithm. 
"""
model_solution(p::Pourcast) = p.model_solution

"""
    scheduling_objective_value(p::Pourcast) -> Real

Return the objective value achieved by the schedule/plan.
"""
scheduling_objective_value(p::Pourcast) = p.scheduling_objective_value





function get_pourfecto_solution_variable(p::Pourcast,var::Symbol)


  m= model_solution(p) 
    if !in(var,keys(m))
      "variable $(var) not found in pourfecto model"
    end 
  return m[var]
end 


vol_sigdigs(p::Pourcast) = -1 * Int(floor(log10(params(p)[:min_vol_threshold])))
  

"""
    transfers(p::Pourcast)

Return the transfer decision variable(s) from a [`Pourcast`](@ref) solution.

This is an accessor that extracts the solver/model variable stored under
the key `:V` from the pourcast's `model_solution`.


# See also
[`flows`](@ref)
"""
function transfers(p::Pourcast)
  sigdigs = vol_sigdigs(p)
  trfs = get_pourfecto_solution_variable(p,:V)
  trfs = round.(trfs;digits=sigdigs)
  return trfs

end 


"""
    flows(p::Pourcast)

Return the flow decision variable(s) from a [`Pourcast`](@ref) solution.

This is an accessor that extracts the solver/model variable stored under
the key `:Q` from the pourcast's `model_solution`

# See also
[`transfers`](@ref), `get_pourfecto_solution_variable`
"""
function flows(p::Pourcast)
  sigdigs = vol_sigdigs(p)
  flws = get_pourfecto_solution_variable(p,:Q)
  flws = round.(flws;digits=sigdigs)
  return flws 
end 


"""
    slacks(p::Pourcast)

Return the slack decision variable(s) from a [`Pourcast`](@ref) solution.

This is an accessor that extracts the solver/model variable stored under
the key `:slacks` from the pourcast's `model_solution`

"""
function slacks(p::Pourcast)
  return get_pourfecto_solution_variable(p,:slacks)
end 






    


"""
    planned_stocks(p::Pourcast) -> Vector{Stock}

Compute the planned  target stocks from a [`Pourcast`](@ref) solution.

This function reconstructs each target stock as a mixture of the source stocks using
the planned transfer volumes from the solution. Conceptually, for each target `t`:

`planned[t] = Σₛ ( V[s,t] * source_stocks(p)[s] )`

where `V` is the transfer-volume decision variable.

## Details
- Transfer volumes are rounded to a number of digits derived from
  `params(p)[:min_vol_threshold]` to reduce numerical noise:
  `digits = -floor(log10(min_vol_threshold))`.
- Volumes are interpreted as microliters and converted to `Unitful` quantities via
  `V .* u"µL"`.

## See Also
[`target_stocks`](@ref)
"""
function planned_stocks(p::Pourcast) 

  
  V = transfers(p)

  V = V .* u"µL"

  #=
  if any(V .< 0u"µL")
    V = map(x-> x >= 0u"µL" ? x : 0u"µL" , V) # deals with numerical issues and numbers being negative 
  end 
  =#
  
  S = source_stocks(p) 
  T = target_stocks(p) 
  planned = Stock[]
    for t in eachindex(T) 
        st = Empty() 
        for s in eachindex(S) 
          st += V[s,t] * S[s]
        end 
      push!(planned,st)
    end 
  return  planned 
end 










