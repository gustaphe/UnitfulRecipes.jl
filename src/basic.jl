#==========
Main recipe
==========#

@recipe function f(::Type{T}, x::T) where T <: AbstractArray{<:Union{Missing,<:Quantity}}
    axisletter = plotattributes[:letter]   # x, y, or z
    if (axisletter == :z) &&
        get(plotattributes, :seriestype, :nothing) ∈ clims_types
        u = get(plotattributes, :zunit, unit(eltype(x)))
        ustripattribute!(plotattributes, :clims, u)
        append_unit_if_needed!(plotattributes, :colorbar_title, u)
    end
    fixaxis!(plotattributes, x, axisletter)
end

function fixaxis!(attr, x, axisletter)
    # Attribute keys
    axislabel = Symbol(axisletter, :guide) # xguide, yguide, zguide
    axislims = Symbol(axisletter, :lims)   # xlims, ylims, zlims
    axisticks = Symbol(axisletter, :ticks) # xticks, yticks, zticks
    err = Symbol(axisletter, :error)       # xerror, yerror, zerror
    axisunit = Symbol(axisletter, :unit)   # xunit, yunit, zunit
    axis = Symbol(axisletter, :axis)       # xaxis, yaxis, zaxis
    # Get the unit
    u = pop!(attr, axisunit, unit(eltype(x)))
    # If the subplot already exists with data, get its unit
    sp = get(attr, :subplot, 1)
    if sp ≤ length(attr[:plot_object]) && attr[:plot_object].n > 0
        label = attr[:plot_object][sp][axis][:guide]
        if label isa UnitfulString
            u = label.unit
        end
        # If label was not given as an argument, reuse
        get!(attr, axislabel, label)
    end
    # Fix the attributes: labels, lims, ticks, marker/line stuff, etc.
    append_unit_if_needed!(attr, axislabel, u)
    ustripattribute!(attr, axislims, u)
    ustripattribute!(attr, axisticks, u)
    ustripattribute!(attr, err, u)
    fixmarkercolor!(attr)
    fixmarkersize!(attr)
    fixlinecolor!(attr)
    # Strip the unit
    ustrip.(u, x)
end

# Recipe for (x::AVec, y::AVec, z::Surface) types
const AVec = AbstractVector
const AMat{T} = AbstractArray{T,2} where T
@recipe function f(x::AVec, y::AVec, z::AMat{T}) where T <: Quantity
    u = get(plotattributes, :zunit, unit(eltype(z)))
    ustripattribute!(plotattributes, :clims, u)
    z = fixaxis!(plotattributes, z, :z)
    append_unit_if_needed!(plotattributes, :colorbar_title, u)
    x, y, z
end

# Recipe for vectors of vectors
@recipe function f(::Type{T}, x::T) where T <: AbstractVector{<:AbstractVector{<:Union{Missing,<:Quantity}}}
    axisletter = plotattributes[:letter]   # x, y, or z
    [fixaxis!(plotattributes, x, axisletter) for x in x]
end

# Recipe for bare units
@recipe function f(::Type{T}, x::T) where T <: Units
    primary := false
    Float64[]*x
end

# Recipes for functions
@recipe function f(f::Function, x::T) where T <: AVec{<:Union{Missing,<:Quantity}}
    x, f.(x)
end
@recipe function f(x::T, f::Function) where T <: AVec{<:Union{Missing,<:Quantity}}
    x, f.(x)
end
@recipe function f(x::T, y::AVec, f::Function) where T <: AVec{<:Union{Missing,<:Quantity}}
    x, y, f.(x',y)
end
@recipe function f(x::AVec, y::T, f::Function) where T <: AVec{<:Union{Missing,<:Quantity}}
    x, y, f.(x',y)
end
@recipe function f(x::T1, y::T2, f::Function) where {T1<:AVec{<:Union{Missing,<:Quantity}}, T2<:AVec{<:Union{Missing,<:Quantity}}}
    x, y, f.(x',y)
end
@recipe function f(f::Function, u::Units)
    uf = UnitFunction(f, [u])
    recipedata = RecipesBase.apply_recipe(plotattributes, uf)
    (_, xmin, xmax) = recipedata[1].args
    return f, xmin*u, xmax*u
end

"""
```julia
UnitFunction
```
A function, bundled with the assumed units of each of its inputs.

```julia
f(x, y) = x^2 + y
uf = UnitFunction(f, u"m", u"m^2")
uf(3, 2) == f(3u"m", 2u"m"^2) == 7u"m^2"
```
"""
struct UnitFunction <: Function
    f::Function
    u::Vector{Units}
end
(f::UnitFunction)(args...) = f.f((args .* f.u)...)

#===============
Attribute fixing
===============#

# Markers / lines
function fixmarkercolor!(attr)
    u = ustripattribute!(attr, :marker_z)
    ustripattribute!(attr, :clims, u)
    u == Unitful.NoUnits || append_unit_if_needed!(attr, :colorbar_title, u)
end
fixmarkersize!(attr) = ustripattribute!(attr, :markersize)
fixlinecolor!(attr) = ustripattribute!(attr, :line_z)

# strip unit from attribute[key]
function ustripattribute!(attr, key)
    if haskey(attr, key)
        v = attr[key]
        u = unit(eltype(v))
        attr[key] = ustrip.(u, v)
        return u
    else
        return Unitful.NoUnits
    end
end
# If supplied, use the unit (optional 3rd argument)
function ustripattribute!(attr, key, u)
    if haskey(attr, key)
        v = attr[key]
        if eltype(v) <: Quantity
            attr[key] = ustrip.(u, v)
        end
    end
    u
end

