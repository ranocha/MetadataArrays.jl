module MetadataArrays

import ArrayInterfaceCore: parent_type, is_forwarding_wrapper, can_setindex,
    can_change_size
using Base: BroadcastStyle
using DataAPI
import DataAPI: metadata, metadatakeys, metadatasupport
using LinearAlgebra

export
    MetadataArray,
    MetadataMatrix,
    MetadataVector,
    metadata,
    metadatakeys

@nospecialize

struct MetadataArray{T, N, P<:AbstractArray,M<:NamedTuple} <: AbstractArray{T, N}
    parent::P
    metadata::M

    global _MDArray(p, md) = new{eltype(p),ndims(p),typeof(p),typeof(md)}(p, md)
end

"""
    MetadataArray(parent::AbstractArray, metadata)

Custom `AbstractArray` object to store an `AbstractArray` `parent` as well as some `metadata`.

# Examples

```jldoctest metadataarray_docs
julia> v = ["John", "John", "Jane", "Louise"];

julia> mdv = MetadataArray(v, groups = Dict("John" => "Treatment", "Louise" => "Placebo", "Jane" => "Placebo"))
4-element MetadataVector{String, Vector{String}, NamedTuple{(:groups,), Tuple{Dict{String, String}}}}:
 "John"
 "John"
 "Jane"
 "Louise"

julia> metadata(mdv, :groups)
Dict{String, String} with 3 entries:
  "John"   => "Treatment"
  "Jane"   => "Placebo"
  "Louise" => "Placebo"

```
"""
MetadataArray(p::AbstractArray, mdn::NamedTuple) = _MDArray(p, mdn)
MetadataArray(p::AbstractArray, md) = MetadataArray(p, NamedTuple(md))
MetadataArray(p::AbstractArray; kwargs...) = MetadataArray(p, values(kwargs))

"""
    MetadataMatrix

Shorthand for `MetadataVector{T,P<:AbstractArray{T,2},M}`.

See also: [`MetadataArray`](@ref), [`MetadataMatrix`](@ref)
"""
const MetadataMatrix{T,P<:AbstractArray{T,2},M} = MetadataArray{T, 2, P, M}
MetadataMatrix(m::AbstractMatrix, md) = MetadataArray(m, md)

"""
    MetadataVector

Shorthand for `MetadataVector{T,P<:AbstractArray{T,1},M}`.

See also: [`MetadataArray`](@ref), [`MetadataMatrix`](@ref)
"""
const MetadataVector{T,P<:AbstractArray{T,1},M} = MetadataArray{T, 1, P, M}
MetadataVector(v::AbstractVector, md) = MetadataArray(v, md)

# avoid new methods for every new parent, metadata type permutation
function Base.convert(T::Type{<:MetadataArray}, mda::MetadataArray)
    if isa(mda, T)
        mda
    else
        MetadataArray(
            convert(parent_type(T), parent(mda)),
            convert(fieldtype(T, :metadata), getfield(mda, :metadata))
        )
    end
end

Base.parent(mda::MetadataArray) = getfield(mda, :parent)
parent_type(T::Type{<:MetadataArray}) = fieldtype(T, :parent)


is_forwarding_wrapper(T::Type{<:MetadataArray}) = true
can_setindex(T::Type{<:MetadataArray}) = can_setindex(parent_type(T))
can_change_size(T::Type{<:MetadataArray}) = can_change_size(parent_type(T))

Base.IndexStyle(T::Type{<:MetadataArray}) = IndexStyle(fieldtype(T, :parent))

Base.iterate(mda::MetadataArray) = iterate(parent(mda))
Base.iterate(mda::MetadataArray, state) = iterate(parent(mda), state)

Base.first(mda::MetadataArray) = first(parent(mda))
Base.step(mda::MetadataArray) = step(parent(mda))
Base.last(mda::MetadataArray) = last(parent(mda))
Base.size(mda::MetadataArray) = size(parent(mda))
Base.axes(mda::MetadataArray) = axes(parent(mda))
Base.strides(mda::MetadataArray) = strides(parent(mda))

Base.length(mda::MetadataArray) = length(parent(mda))
Base.firstindex(mda::MetadataArray) = firstindex(parent(mda))
Base.lastindex(mda::MetadataArray) = lastindex(parent(mda))
Base.pointer(mda::MetadataArray) = pointer(parent(mda))

Base.in(val, mda::MetadataArray) = in(val, parent(mda))
Base.sizehint!(mda::MetadataArray, n::Integer) = sizehint!(parent(mda), n)
Base.keys(mda::MetadataArray) = keys(parent(mda))
Base.isempty(mda::MetadataArray) = isempty(parent(mda))

Base.dataids(mda::MetadataArray) = (Base.dataids(parent(mda))..., Base.dataids(getfield(mda, :metadata))...)

Base.propertynames(mda::MetadataArray) = keys(getfield(mda, :metadata))
Base.getproperty(mda::MetadataArray, s::Symbol) = getfield(getfield(mda, :metadata), s)
Base.getproperty(mda::MetadataArray, s::String) = getproperty(mda, Symbol(s))
Base.hasproperty(mda::MetadataArray, s::Symbol) = haskey(getfield(mda, :metadata), s)
Base.hasproperty(mda::MetadataArray, s::String) = hasproperty(mda, Symbol(s))

function metadata(mda::MetadataArray, key::AbstractString; style=nothing)
    metadata(mda, Symbol(key); style=style)
end
function metadata(mda::MetadataArray, key::AbstractString, default; style=nothing)
    metadata(mda, Symbol(key), default; style=style)
end
@inline function metadata(mda::MetadataArray, key::Symbol; style=nothing)
    _metadata(getproperty(mda, key), style)
end
@inline function metadata(mda::MetadataArray, key::Symbol, default; style=nothing)
    _metadata(get(getfield(mda, :metadata), key, default), style)
end
_metadata(md, ::Nothing) = md
_metadata(md, style::Bool) = style ? (md, :default) : md
metadatakeys(mda::MetadataArray) = propertynames(mda)
metadatasupport(T::Type{<:MetadataArray}) = (read=true, write=false)
dropmeta(mda::MetadataArray) = parent(mda)
dropmeta(x) = x

@specialize
@inline function Base.similar(mda::MetadataArray)
    _MDArray(similar(parent(mda)), getfield(mda, :metadata))
end
@inline function Base.similar(mda::MetadataArray, ::Type{T}) where {T}
    _MDArray(similar(parent(mda), T), getfield(mda, :metadata))
end
function Base.similar(mda::MetadataArray, ::Type{T}, dims::Dims) where {T}
    _MDArray(similar(parent(mda), T, dims), getfield(mda, :metadata))
end

function Base.reshape(s::MetadataArray, d::Dims)
    MetadataArray(reshape(parent(s), d), getfield(mda, :metadata))
end
Base.@propagate_inbounds Base.getindex(mda::MetadataArray, i::Int...) = parent(mda)[i...]
Base.@propagate_inbounds function Base.getindex(mda::MetadataArray, inds...)
    _MDArray(parent(mda)[inds...], getfield(mda, :metadata))
end
Base.@propagate_inbounds function Base.setindex!(mda::MetadataArray, val, inds...)
    setindex!(parent(mda),val, inds...)
end

#region broadcast
"""
    MetadataArrayStyle{S}

Subtype of `BroadcastStyle` for `MetadataArray`, where `S` is the `BroadcastStyle`
of the parent array. This helps extract, combine, and propagate metadata from arrays.
"""
struct MetadataArrayStyle{S<:BroadcastStyle} <: Broadcast.AbstractArrayStyle{Any} end
MetadataArrayStyle(::S) where {S} = MetadataArrayStyle{S}()
MetadataArrayStyle(::S, ::Val{N}) where {S,N} = MetadataArrayStyle(S(Val(N)))
MetadataArrayStyle(::Val{N}) where {N} = MetadataArrayStyle{Broadcast.DefaultArrayStyle{N}}()
function MetadataArrayStyle(a::BroadcastStyle, b::BroadcastStyle)
    style = BroadcastStyle(a, b)
    if style === Broadcast.Unknown()
        return Broadcast.Unknown()
    else
        return MetadataArrayStyle(style)
    end
end
function Base.BroadcastStyle(T::Type{<:MetadataArray})
    MetadataArrayStyle{typeof(BroadcastStyle(parent_type(T)))}()
end
function Base.BroadcastStyle(::MetadataArrayStyle{A}, ::MetadataArrayStyle{B}) where {A,B}
    style = BroadcastStyle(A(), B())
    isa(style, Broadcast.Unknown) ? Broadcast.Unknown() : MetadataArrayStyle(style)
end

# Resolve ambiguities
# for all these cases, we define that we win to be the outer style regardless of order
for B in (:BroadcastStyle, :(Broadcast.DefaultArrayStyle), :(Broadcast.AbstractArrayStyle), :(Broadcast.Style{Tuple}),)
    @eval begin
        #Base.BroadcastStyle(::MetadataArrayStyle{A}, b::$B) where {A} = MetadataArrayStyle(A(), b)
        Base.BroadcastStyle(b::$B, ::MetadataArrayStyle{A}) where {A} = MetadataArrayStyle(b, A())
    end
end

# TODO need combine_metadata to extract metadata info correctly
# We need to implement copy because if the wrapper array type does not support setindex
# then the `similar` based default method will not work
function Broadcast.copy(bc::Broadcast.Broadcasted{MetadataArrayStyle{S}}) where {S}
    copy(Broadcast.Broadcasted{S}(bc.f, map(dropmeta, bc.args), axes(bc)))
end
#endregion


end # module
