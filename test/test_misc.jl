using JuliaDB
using Base.Test

@testset "extractarray" begin

    t = IndexedTable(Columns(a=[1,1,1,2,2], b=[1,2,3,1,2]),
                     Columns(c=[1,2,3,4,5], d=[5,4,3,2,1]))
    for i=[2, 3, 5]
        d = compute(distribute(t, i))
        dist = map(get, map(JuliaDB.nrows, d.subdomains))
        @test map(length, Dagger.domainchunks(getindexcol(d, 1))) == dist
        @test collect(getindexcol(d, 2)) == t.index.columns[2]
        @test collect( getdatacol(d, 2)) == t.data.columns[2]
    end
end

@testset  "printing" begin
    x = distribute(IndexedTable([1], [1]), 1)
    @test sprint(io -> show(io, x)) == """
    DTable with 1 rows in 1 chunks:

    ──┬──
    1 │ 1"""
end

import JuliaDB: chunks, index_spaces, has_overlaps
@testset "has_overlaps" begin
    t = IndexedTable(Columns([1,1,2,2,2,3], [1,2,1,1,2,1]), [1,2,3,4,5,6])
    d = distribute(t, [2,3,1])
    i = d.subdomains
    @test !has_overlaps(i)
    @test !has_overlaps(i, true)

    d = distribute(t, [2,2,2])
    i = d.subdomains
    @test !has_overlaps(i)
    @test !has_overlaps(i, true)

    d = distribute(t, [2,1,3])
    i = d.subdomains
    @test !has_overlaps(i)
    @test has_overlaps(i, true)
end

import JuliaDB: with_overlaps, delayed
@testset "with_overlaps" begin
    t = IndexedTable([1,1,2,2,2,3], [1,2,3,4,5,6])
    d = distribute(t, [2,2,2])
    group_count = 0
    t1 = with_overlaps(d) do cs
        if length(cs) > 1
            group_count += 1
            @test length(cs) == 2
            @test collect(cs[1]) == IndexedTable([2,2], [3,4])
            @test collect(cs[2]) == IndexedTable([2,3], [5,6])
            return delayed((x,y) -> merge(x,y,agg=nothing))(cs...)
        else
            cs[1]
        end
    end
    @test collect(aggregate(+, t1)) == aggregate(+, t)
    @test group_count == 1
end
