function basicgeometry(f::GeoJSONTables.Feature)
    geom = geometry(f)
    prop = properties(f)
    return basicgeometry(geom, prop)
end

function basicgeometry(geom::JSON3.Object, prop::JSON3.Object)
    t = geom.type
    k = keys(prop)
    v = values(prop)
    tup = (; zip(k, v)...)
    println(tup)
    if t == "Point"
        return basicgeometry(Point, geom.coordinates, tup)
    elseif t == "LineString"
        return basicgeometry(LineString, geom.coordinates, tup)
    elseif t == "Polygon"
        return basicgeometry(Polygon, geom.coordinates, tup)
    elseif t == "MultiPoint"
        return basicgeometry(MultiPoint, geom.coordinates, tup)
    elseif t == "MultiLineString"
        return basicgeometry(MultiLineString, geom.coordinates, tup)
    elseif t == "MultiPolygon"
        return basicgeometry(MultiPolygon, geom.coordinates, tup)
    elseif t == "FeatureCollection"
        return basicgeometry(FeatureCollection, geom.geometries, tup)
    else
        throw(ArgumentError("Unknown geometry type"))
    end
end

function basicgeometry(::Type{Point}, g::JSON3.Array, tup::NamedTuple)
    pt = Point{2, Float64}(g)
    return GeometryBasics.Meta(pt, tup)
end

function basicgeometry(::Type{Point}, g::JSON3.Array)
    return Point{2, Float64}(g)
end

function basicgeometry(::Type{LineString} , g::JSON3.Array, tup::NamedTuple)
    ls = LineString([Point{2, Float64}(p) for p in g], 1)
    return Meta(ls, tup)
end

function basicgeometry(::Type{LineString} , g::JSON3.Array)
    return LineString([Point{2, Float64}(p) for p in g], 1)
end

function basicgeometry(::Type{Polygon}, g::JSON3.Array, tup::NamedTuple)
    # TODO introduce LinearRing type in GeometryBasics?
    nring = length(g)
    exterior = LineString([Point{2, Float64}(p) for p in g[1]], 1)
    if nring == 1  # only exterior
        poly =  Polygon(exterior)
        return PolygonMeta(poly, tup)
    else  # exterior and interior(s)
        interiors = Vector{typeof(exterior)}(undef, nring)
        for i in 2:nring
            interiors[i-1] = LineString([Point{2, Float64}(p) for p in g[i]], 1)
        end
        poly =  Polygon(exterior, interiors)
        return PolygonMeta(poly, tup)
    end
end

function basicgeometry(::Type{Polygon}, g::JSON3.Array)
    # TODO introduce LinearRing type in GeometryBasics?
    nring = length(g)
    exterior = LineString([Point{2, Float64}(p) for p in g[1]], 1)
    if nring == 1  # only exterior
        return Polygon(exterior)
    else  # exterior and interior(s)
        interiors = Vector{typeof(exterior)}(undef, nring)
        for i in 2:nring
            interiors[i-1] = LineString([Point{2, Float64}(p) for p in g[i]], 1)
        end
        return Polygon(exterior, interiors)
    end
end


function basicgeometry(::Type{MultiPoint}, g::JSON3.Array, tup::NamedTuple)
    return MultiPointMeta([basicgeometry(Point, x) for x in g], tup)
end

function basicgeometry(::Type{MultiLineString}, g::JSON3.Array, tup::NamedTuple)
    return MultiLineStringMeta([basicgeometry(LineString, x) for x in g], tup)
end

function basicgeometry(::Type{MultiPolygon}, g::JSON3.Array, tup::NamedTuple)
    poly = [basicgeometry(Polygon, x) for x in g]
    return MultiPolygon(poly; tup...)
end

function basicgeometry(::Type{FeatureCollection}, g::JSON3.Array, tup::NamedTuple)
    #todo workout a way to represent metadata in this case
    return [basicgeometry(geom) for geom in g] 
end

# @btime GeoJSONTables.read($bytes_ne_10m_land)
# # 53.805 ms (17 allocations: 800 bytes)
# @btime [basicgeometry(f) for f in $t]
# # 446.689 ms (2990547 allocations: 150.06 MiB)

# # the file contains 9 MultiPolygons followed by 1 Polygon
# # so StructArrays only works if we take the first 9 only

# sa = StructArray([basicgeometry(f) for f in take(t, 9)])
# sa = StructArray([basicgeometry(f) for f in t])
