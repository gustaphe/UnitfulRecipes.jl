module UnitfulRecipes

using RecipesBase
using Unitful: Quantity, unit, ustrip, Unitful, dimension, Units
export @P_str

include("basic.jl")
include("labels.jl")

end # module
