module UnitfulRecipes

using RecipesBase
using Unitful: Quantity, unit, ustrip, Unitful, dimension, Units
using Infiltrator
export @P_str

const clims_types = (:contour, :contourf, :heatmap, :surface)

#==========
Main recipe
==========#

@recipe function f(::Type{T}, x::T) where T <: AbstractArray{<:Union{Missing,<:Quantity}}
    axisletter = plotattributes[:letter]   # x, y, or z
    if (axisletter == :z) && get(plotattributes, :seriestype, :nothing) ∈ clims_types
        # I don't know why fill_z gets turned into a Vector, it needs to be reshaped back
        plotattributes[:fill_z] = reshape(
             get(plotattributes, :fill_z, x),
             size(x)...
            )
    end
    fixaxis!(plotattributes, x, axisletter)
end

function fixaxis!(attr, x, axisletter)
    # Attribute keys
    axislabel = Symbol(axisletter, :guide) # xguide, yguide, zguide
    axislims = Symbol(axisletter, :lims)   # xlims, ylims, zlims
    axisticks = Symbol(axisletter, :ticks) # xticks, yticks, zticks
    err = Symbol(axisletter, :error)       # xerror, yerror, zerror

    u = fixlabel!(attr, axisletter, unit(first(x)))
    # Fix the attributes: labels, lims, ticks, marker/line stuff, etc.
    append_unit_if_needed!(attr, axislabel, u)
    ustripattribute!(attr, axislims, u)
    ustripattribute!(attr, axisticks, u)
    ustripattribute!(attr, err, u)
    fixcolors!(attr)
    fixmarkersize!(attr)
    # Strip the unit
    return ustrip.(u, x)
end

function fixlabel!(attr, axisletter, dataunit)
    u = pop!(attr, Symbol(axisletter,:unit), dataunit)
    sp = get(attr, :subplot, 1)
    if axisletter == :c
        labelname = :colorbar_title
        axisname = nothing
    else
        labelname = :guide
        axisname = Symbol(axisletter, :axis)
    end
    if sp ≤ length(attr[:plot_object]) && attr[:plot_object].n > 0
        label = getlabel(attr, sp, axisname, labelname)
        if label isa UnitfulString
            u = label.unit
        end
        get!(attr, labelname, label)
    end
    return u
end
getlabel(attr, sp, axisname, labelname) = attr[:plot_object][sp][axisname][labelname]
getlabel(attr, sp, axisname::Nothing, labelname) = attr[:plot_object][sp][labelname]


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

const AVec = AbstractVector
const AMat{T} = AbstractArray{T,2} where T

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
function fixcolors!(attr)
    u = unit(first(get(attr, :line_z, get(attr, :marker_z, get(attr, :fill_z, [1])))))
    u = fixlabel!(attr, :c, u)
    for key in [:line_z, :marker_z, :fill_z, :clims]
        ustripattribute!(attr, key, u)
    end
    append_unit_if_needed!(attr, :colorbar_title, u)
end
fixmarkersize!(attr) = ustripattribute!(attr, :markersize)

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

#=======================================
Label string containing unit information
=======================================#

abstract type AbstractProtectedString <: AbstractString end
struct ProtectedString{S} <: AbstractProtectedString
    content::S
end
struct UnitfulString{S,U} <: AbstractProtectedString
    content::S
    unit::U
end
# Minimum required AbstractString interface to work with Plots
const S = AbstractProtectedString
Base.iterate(n::S) = iterate(n.content)
Base.iterate(n::S, i::Integer) = iterate(n.content, i)
Base.codeunit(n::S) = codeunit(n.content)
Base.ncodeunits(n::S) = ncodeunits(n.content)
Base.isvalid(n::S, i::Integer) = isvalid(n.content, i)
Base.pointer(n::S) = pointer(n.content)
Base.pointer(n::S, i::Integer) = pointer(n.content, i)
"""
    P_str(s)

Creates a string that will be Protected from recipe passes.

Example:
```julia
julia> plot(rand(10)*u"m", xlabel=P"This label is protected")

julia> plot(rand(10)*u"m", xlabel=P"This label is not")
```
"""
macro P_str(s)
    return ProtectedString(s)
end


#=====================================
Append unit to labels when appropriate
=====================================#

function append_unit_if_needed!(attr, key, u::Unitful.Units)
    label = get(attr, key, nothing)
    append_unit_if_needed!(attr, key, label, u)
end
# dispatch on the type of `label`
append_unit_if_needed!(attr, key, label::ProtectedString, u) = nothing
append_unit_if_needed!(attr, key, label::UnitfulString, u) = nothing
function append_unit_if_needed!(attr, key, label::Nothing, u)
    attr[key] = UnitfulString(string(u), u)
end
function append_unit_if_needed!(attr, key, label::S, u) where {S <: AbstractString}
    if !isempty(label)
        attr[key] = UnitfulString(S(format_unit_label(label, u, get(attr, :unitformat, :round))), u)
    end
end

#=============================================
Surround unit string with specified delimiters
=============================================#
format_unit_label(l, u, f::Nothing) = string(l, ' ', u)
format_unit_label(l, u, f::Function) = f(l, u)
format_unit_label(l, u, f::AbstractString) = string(l, f, u)
format_unit_label(l, u, f::NTuple{2, <:AbstractString}) = string(l, f[1], u, f[2])
format_unit_label(l, u, f::NTuple{3, <:AbstractString}) = string(f[1], l, f[2], u, f[3])
format_unit_label(l, u, f::Char) = string(l, ' ', f, ' ', u)
format_unit_label(l, u, f::NTuple{2, Char}) = string(l, ' ', f[1], u, f[2])
format_unit_label(l, u, f::NTuple{3, Char}) = string(f[1], l, ' ', f[2], u, f[3])
format_unit_label(l, u, f::Bool) = f ? format_unit_label(l, u, :round) : format_unit_label(l, u, nothing)

const UNIT_FORMATS = Dict(
                          :round => ('(', ')'),
                          :square => ('[', ']'),
                          :curly => ('{', '}'),
                          :angle => ('<', '>'),
                          :slash => '/',
                          :slashround => (" / (", ")"),
                          :slashsquare => (" / [", "]"),
                          :slashcurly => (" / {", "}"),
                          :slashangle => (" / <", ">"),
                          :verbose => " in units of ",
                         )

format_unit_label(l, u, f::Symbol) = format_unit_label(l,u,UNIT_FORMATS[f])

end # module
