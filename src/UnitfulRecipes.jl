module UnitfulRecipes

using RecipesBase
using Unitful: Quantity, Unitful, Units, Level, Gain, NoUnits
using Unitful: unit, ustrip, dimension, linear, uconvertp

export @P_str

include("basic.jl")
include("labels.jl")
include("logarithmic.jl")

end # module
