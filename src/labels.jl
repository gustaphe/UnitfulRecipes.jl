const clims_types = (:contour, :contourf, :heatmap, :surface)

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

