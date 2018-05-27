"""
    MetadataArray(parent::AbstractArray, metadata)

Custom `AbstractArray` object to store an `AbstractArray` `parent` as well as some `metadata`.

# Examples

```jldoctest metadataarray
julia> v = ["John", "John", "Jane", "Louise"];

julia> s = MetadataArray(v, Dict("John" => "Treatment", "Louise" => "Placebo", "Jane" => "Placebo"))
4-element MetadataArrays.MetadataArray{String,Dict{String,String},1,Array{String,1}}:
 "John"
 "John"
 "Jane"
 "Louise"

julia> metadata(s)
Dict{String,String} with 3 entries:
  "John"   => "Treatment"
  "Jane"   => "Placebo"
  "Louise" => "Placebo"
```
"""
struct MetadataArray{T, M, N, S<:AbstractArray} <: AbstractArray{T, N}
    parent::S
    metadata::M
end

MetadataArray(v::AbstractArray{T, N}, m::M = ()) where {T, N, M} =
     MetadataArray{T, M, N, typeof(v)}(v, m)

"""
    MetadataVector{T, M, S<:AbstractArray}

Shorthand for `MetadataArray{T, M, 1, S}`.
"""
const MetadataVector{T, M, S<:AbstractArray} = MetadataArray{T, M, 1, S}

MetadataVector(v::AbstractVector, n = ()) = MetadataArray(v, n)

Base.size(s::MetadataArray) = Base.size(parent(s))

Base.IndexStyle(T::Type{<:MetadataArray{}}) = IndexStyle(_parent_type(T))

Base.getindex(s::MetadataArray, x::Int) = getindex(parent(s), x)

function Base.getindex(s::MetadataArray{T, M, N}, x::Vararg{Int, N}) where {T, M, N}
    getindex(parent(s), x...)
end

function Base.getindex(s::MetadataArray, x...)
    _metadata_array(getindex(parent(s), x...), metadata(s))
end

Base.setindex!(s::MetadataArray, el, x::Int) = setindex!(parent(s), el, x)

function Base.setindex!(s::MetadataArray{T, M, N}, el, x::Vararg{Int, N}) where {T, M, N}
    setindex!(parent(s), el, x...)
end

Base.parent(s::MetadataArray) = s.parent

_parent_type(::Type{MetadataArray{T, M, N, S}}) where {T,M,N,S} = S

"""
    metadata(s::MetadataArray)

Returns metadata for `s`.
"""
metadata(s::MetadataArray) = s.metadata

metadata(s::SubArray) = metadata(parent(s))

metadata(s::T) where {T<:AbstractArray} =
    error("Type $T has no method for metadata")

_metadata_array(v::AbstractArray, m) = MetadataArray(v, m)
_metadata_array(v, m) = v

Base.similar(A::MetadataArray, ::Type{S}, dims::Dims) where S =
    MetadataArray(similar(parent(A), S, dims), metadata(A))
