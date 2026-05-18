    struct MixingError <:Exception
        msg::AbstractString
        constraints::Vector{JuMP.ConstraintRef}
     end
        
    struct OverdraftError <: Exception 
        msg::AbstractString
        balances::Dict{JLIMS.Stock,Unitful.Quantity}
    end 
    

    
    struct ChemicalShortageError <: Exception 
        msg::AbstractString
        balances::Dict{JLIMS.Chemical,Unitful.Quantity}
    end 
    
    
    struct StockCompatibilityError <: Exception 
        msg::AbstractString 
    end 
