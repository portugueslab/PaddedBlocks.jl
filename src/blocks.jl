struct Blocks{N}
    full_size::NTuple{N,Int64}
    block_size::NTuple{N,Int64}
    crop_start::NTuple{N,Int64}
    crop_end::NTuple{N,Int64}
    padding::NTuple{N,Int64}
    blocks_per_dim::NTuple{N,Int64}
end

function Base.:*(a::Blocks, b::Blocks)
    return Blocks(
        (a.full_size..., b.full_size...),
        (a.block_size..., b.block_size...),
        (a.crop_start..., b.crop_start...),
        (a.crop_end..., b.crop_end...),
        (a.padding..., b.padding...),
        (a.blocks_per_dim..., b.blocks_per_dim...),
    )
end

"Completes a partially-specified indexing expression"
function complete_index(s, full_size)
    return I = tuple((
        isa(se, Colon) ? (1:full_size[d]) : (isa(se, Int) ? (se:se) : se) for
        (d, se) in enumerate(s)
    )...)
end

"""
Constructs a structure helpful with splitting arrays into blocks with padding

$(SIGNATURES)

"""
function Blocks(
    full_size::NTuple{N,Int64},
    block_size::NTuple{N,Union{Int64,Colon}},
    crop_start::NTuple{N,Int64},
    crop_end::NTuple{N,Int64},
    padding::NTuple{N,Int64},
) where {N}
    block_size = tuple((isa(k, Colon) ? s : k for (k, s) in zip(block_size, full_size))...)
    blocks_per_dim = tuple(ceil.(
        Int64,
        (full_size .- crop_start .- crop_end .- padding) ./ block_size,
    )...)
    return Blocks(full_size, block_size, crop_start, crop_end, padding, blocks_per_dim)
end

function Blocks(
    full_size::NTuple{N,Int64},
    block_size::NTuple{N,Union{Int64,Colon}};
    crop_start::Union{Nothing,NTuple{N,Int64}} = nothing,
    crop_end::Union{Nothing,NTuple{N,Int64}} = nothing,
    padding::Union{Nothing,NTuple{N,Int64}} = nothing,
) where {N}
    zt = tuple((0 for i in 1:N)...)
    return Blocks(
        full_size,
        block_size,
        crop_start === nothing ? zt : crop_start,
        crop_end === nothing ? zt : crop_end,
        padding === nothing ? zt : padding,
    )
end

function Base.length(b::Blocks)
    return reduce(*, b.blocks_per_dim)
end

function starts_ends(b::Blocks{N}) where {N}
    block_starts = Array{Int64}(undef, b.blocks_per_dim..., N)
    block_ends = similar(block_starts)
    for idx_blocks in CartesianIndices(size(block_starts)[1:end-1])
        block_starts[idx_blocks, :] .=
            1 .+ b.crop_start .+ (idx_blocks.I .- 1) .* b.block_size
        block_ends[idx_blocks, :] .=
            min.(
                b.full_size .- b.crop_end,
                idx_blocks.I .* b.block_size .+ b.crop_start .+ b.padding,
            )
    end
    return block_starts, block_ends
end

function slices(b::Blocks)
    starts, ends = starts_ends(b)
    i2s = CartesianIndices(b.blocks_per_dim)
    return [
        tuple(((s:e) for (s, e) in zip(starts[i2s[i], :], ends[i2s[i], :]))...)
        for i in 1:length(b)
    ]
end

"""
Given an indexing expression, return which blocks to take and which parts of them to include

$(SIGNATURES)

"""
function blocks_to_take(
    b::Blocks{N},
    block_starts::Array{Int64},
    block_ends::Array{Int64},
    s::NTuple{N,Union{Int,Colon,AbstractRange}},
) where {N}
    I = complete_index(s, b.full_size)
    file_slices = Array{Int64,2}(undef, (2, N))
    block_slices = Array{Int64,2}(undef, (2, N))
    for d in 1:N
        start = I[d].start
        stop = I[d].stop
        axis_index = tuple(((i == d) ? Colon() : 1 for i in 1:N)..., d)
        s = searchsortedlast(block_starts[axis_index...], start)
        e = searchsortedlast(block_starts[axis_index...], stop)
        block_start = start - block_starts[axis_index...][s] + 1
        block_end = stop - block_starts[axis_index...][e] + 1
        file_slices[:, d] .= [s, e]
        block_slices[:, d] .= [block_start, block_end]
    end
    return file_slices, block_slices
end

function blocks_to_take(b::Blocks{N}, s::NTuple{N,Union{Int,Colon,AbstractRange}}) where {N}
    return blocks_to_take(b, starts_ends(b)..., s)
end

function blocks_containing(
    b::Blocks{N},
    block_starts::Array{Int64},
    block_ends::Array{Int64},
    s::NTuple{N,Union{Int,Colon,AbstractRange}},
) where {N}
    I = complete_index(s, b.full_size)
    return tuple((
        begin

            start = I[d].start
            stop = I[d].stop
            axis_index = tuple(((i == d) ? Colon() : 1 for i in 1:N)..., d)
            lo, up = searchsortedlast.(Ref(block_starts[axis_index...]), [start, stop])
            lo:up
        end for d in 1:N
    )...)

end

# Define JSON serialization
JSON3.StructType(::Type{<:Blocks}) = JSON3.Struct()

function save(filename, b::Blocks)
    return open(filename, "w") do f
        return write(f, JSON3.write(b))
    end
end

function load_blocks(filename)
    return open(filename, "r") do f
        return JSON3.read(f, Blocks)
    end
end