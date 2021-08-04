# `1u"dBm" isa Level`
# Plotted as its linear value, but by default on a logarithmic axis
@recipe function f(::Type{T}, x::T) where T <: AbstractArray{<:Level}
    scale := :log10
    return linear.(x)
end

# `1u"dB" isa Gain`
# Plotted as its linear (power) value, but by default on a logarirthmic axis
@recipe function f(::Type{T}, x::T) where T <: AbstractArray{<:Gain}
    scale := :log10
    return uconvertp.(NoUnits, x)
end

# `1u"dB/m" isa Quantity{<:Gain}
# Plotted as-is, 0.01/m is not the same thing as -20u"dB/m"
#= Not implemented
@recipe function f(::Type{T}, x::T) where T <: AbstractArray{<:Quantity{<:Gain}}

end
=#
