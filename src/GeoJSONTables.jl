module GeoJSONTables

import JSON3, Tables, GeoFormatTypes, GeoInterface, Extents

struct FeatureCollection{O,A} <: AbstractVector{eltype(A)}
    object::O
    array::A
end

"Access the JSON3.Object that represents the FeatureCollection"
object(f::FeatureCollection) = f.object

"Access the JSON3.Array that represents the FeatureCollection"
array(f::FeatureCollection) = f.array

read(source::GeoFormatTypes.GeoJSON) = read(GeoFormatTypes.val(source))
function read(source)
    object = JSON3.read(source)
    object_type = get(object, :type, nothing)
    if object_type == "FeatureCollection"
        features = get(object, :features, nothing)
        features isa JSON3.Array || error("GeoJSON field \"features\" is not an array")
        FeatureCollection(object, features)
    elseif object_type == "Feature"
        Feature(object)
    elseif object_type == nothing
        error("String does not follow the GeoJSON specification: must have a \"features\" field")
    else
        geometry(object)
    end
end

Tables.istable(::Type{<:FeatureCollection}) = true
Tables.rowaccess(::Type{<:FeatureCollection}) = true
Tables.rows(fc::FeatureCollection) = fc

Base.IteratorSize(::Type{<:FeatureCollection}) = Base.HasLength()
Base.length(fc::FeatureCollection) = length(array(fc))
Base.IteratorEltype(::Type{<:FeatureCollection}) = Base.HasEltype()

# read only AbstractVector
Base.size(fc::FeatureCollection) = size(array(fc))
Base.getindex(fc::FeatureCollection, i) = Feature(array(fc)[i])
Base.IndexStyle(::Type{<:FeatureCollection}) = IndexLinear()

miss(x) = ifelse(x === nothing, missing, x)

struct Feature{T}
    object::T
end

# these features always have type="Feature", so exclude that
# the keys in properties are added here for direct access
Base.propertynames(f::Feature) = keys(properties(f))

"Access the properties JSON3.Object of a Feature"
properties(f::Feature) = object(f).properties

"Access the JSON3.Object that represents the Feature"
object(f::Feature) = getfield(f, :object)

"Access the JSON3.Object that represents the Feature's geometry"
geometry(f::Feature) = geometry(object(f).geometry)

"""
Convert a GeoJSON geometry from JSON object to a struct specific
to that geometry type.
"""
function geometry(g::JSON3.Object)
    t = g.type
    if t == "Point"
        Point(g.coordinates)
    elseif t == "LineString"
        LineString(g.coordinates)
    elseif t == "Polygon"
        Polygon(g.coordinates)
    elseif t == "MultiPoint"
        MultiPoint(g.coordinates)
    elseif t == "MultiLineString"
        MultiLineString(g.coordinates)
    elseif t == "MultiPolygon"
        MultiPolygon(g.coordinates)
    elseif t == "GeometryCollection"
        GeometryCollection(g.geometries)
    else
        throw(ArgumentError("Unknown geometry type"))
    end
end
geometry(g::Nothing) = nothing


"""
Get a specific property of the Feature

Returns missing for null/nothing or not present, to work nicely with
properties that are not defined for every feature. If it is a table,
it should in some sense be defined.
"""
function Base.getproperty(f::Feature, nm::Symbol)
    props = properties(f)
    val = get(props, nm, missing)
    miss(val)
end

@inline function Base.iterate(fc::FeatureCollection)
    st = iterate(array(fc))
    st === nothing && return nothing
    val, state = st
    return Feature(val), state
end

@inline function Base.iterate(fc::FeatureCollection, st)
    st = iterate(array(fc), st)
    st === nothing && return nothing
    val, state = st
    return Feature(val), state
end

Base.show(io::IO, fc::FeatureCollection) = println(io, "FeatureCollection with $(length(fc)) Features")
function Base.show(io::IO, f::Feature)
    geom = array(f).geometry
    if isnothing(geom)
        print(io, "Feature without geometry")
    else
        print(io, "Feature with geometry type $(object(f).geometry.type)")
    end
    print(io, ", and properties: $(propertynames(f))")
end
Base.show(io::IO, ::MIME"text/plain", fc::FeatureCollection) = show(io, fc)
Base.show(io::IO, ::MIME"text/plain", f::Feature) = show(io, f)

bbox(f::Union{Feature,FeatureCollection}) = get(object(f), :bbox, nothing)

function GeoInterface.extent(f::Union{Feature,FeatureCollection})
    bb = bbox(f)
    if isnothing(bb)
        return nothing
    else
        if length(bb) == 4
            return Extents.Extent(X=(bb[1], bb[3]), Y=(bb[2], bb[4]))
        elseif length(bb) == 6
            return Extents.Extent(X=(bb[1], bb[4]), Y=(bb[2], bb[5]), Z=(bb[3], bb[6]))
        else
            error("Intcorrently specified bbox: must have 4 or 6 values")
        end
    end
end
GeoInterface.crs(f::Union{Feature,FeatureCollection,Geometry}) = GeoFormatTypes.EPSG(4326)

include("geomtypes.jl")
include("geointerface.jl")

end # module
