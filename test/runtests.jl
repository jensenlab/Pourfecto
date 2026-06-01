using Pourfecto
using Test, JLIMS, Unitful, AbstractTrees, CSV, DataFrames , Random

import Pourfecto: # from instruments folder 
    SingleChannel, EightChannel

import Pourfecto: # from types 
    Configuration, Mask,
    head,channels, asp, disp ,asp_positions, disp_positions, labware,
    AspNode, DispNode,
    Pourcast, transfers, flows 

import Pourfecto: # default_labware 
    SLASLabware, Bottle, Conical, 
    generate, well_to_cartesian, cartesian_to_well

import Pourfecto: #mask utils 
    compute_positions

import Pourfecto: # dataframe_interface.jl
    vc_to_stock, stock_to_vc, q_to_stock, stock_to_q, vc_to_q,q_to_vc

import Pourfecto: # pourfecto_algorithms/helpers.jl
    normalize_inputs , check_inputs, well_connections, compute_flow_nodes





include("compute_positions.jl")
include("masks.jl")
include("dataframe_interface.jl")
include("well_connections.jl")
include("json_interface.jl")

function all_planned_approx_target(p::Pourcast;kwargs...)
    ps = planned_stocks(p) 
    ts = target_stocks(p)

    return all([JLIMS.isapprox(ps[i],ts[i];kwargs...) for i in eachindex(ps)])
end 



include("test_problems/test_compilation.jl")
include("test_problems/checkerboard.jl")
#include("test_problems/combinatorial_media.jl")
include("test_problems/labware_stamping.jl")
include("test_problems/mantis_pcr.jl")
include("test_problems/tempest_compilation.jl")
include("test_problems/cobra_compilation.jl")
include("test_problems/nimbus_compilation.jl")


