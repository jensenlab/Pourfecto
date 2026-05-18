
function in_mask_bounds(L::Tuple{Integer,Integer},P::Tuple{Integer,Integer},H::Tuple{Integer,Integer},w::Integer,p::Integer,c::Integer)
    1 <= w <= prod(L) || return false 
    1 <= p <= prod(P) || return false 
    1 <= c <= prod(H) || return false 
    return true 
end 

function cartesian(x::Tuple{Integer,Integer},i::Integer)
    return Tuple(CartesianIndices(x)[i])
end 


function linear_to_cartesian(L::Tuple{Integer,Integer},P::Tuple{Integer,Integer},H::Tuple{Integer,Integer},w::Integer,p::Integer,c::Integer)
        wi,wj = cartesian(L,w) 
        pm,pn = cartesian(P,p) # not using pi and pj because of the constant pi 
        ci,cj = cartesian(H,c)
        return wi,wj,pm,pn,ci,cj 
end 



function compute_positions(h::Head,l::Labware;kwargs...) 
    return compute_positions(compute_mask_sizes(h,l)...;kwargs...)
end 



function compute_positions(H::Tuple{Int64,Int64}, L::Tuple{Int64,Int64}; v_out::Bool=false,h_out::Bool=false, v_spacing::Integer = 1, h_spacing::Integer=1)




r_adj = v_out ? v_spacing * H[1] -1 - (v_spacing-1) : - v_spacing *H[1] + 1 + (v_spacing -1)
c_adj = h_out ? h_spacing * H[2] -1 -(h_spacing-1) : -h_spacing * H[2] + 1 +(h_spacing -1)

return max.(L .+ (r_adj,c_adj), (0,0))
    


end 


function compute_mask_sizes(h::Head, l::Labware)
        H = size(channels(h))
        if H isa Tuple{Integer} # finds case where the channels are just a vector. Size returns a tuple (x,) 
            H = (H[1],1)
        end 
        L = shape(l) # JLIMS function 
        return H,L 
end 


