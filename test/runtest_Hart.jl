using Revise
using UnitfulLinearAlgebra
using Unitful
using LinearAlgebra
using Test

# test/learn from Hart's book

@testset "UnitfulLinearAlgebra.jl" begin
    # Write your tests here.

    @testset "scalars" begin
        c = 1u"m"
        d = 2u"m"
        @test c~d
        @test similar(c,d)
        @test rand() ~ rand()
        @test parallel(rand(),rand())
        @test rand() ∥ rand()
        @test uniform(rand())
        @test uniform((rand())u"K")
        @test isequal(invdimension(1.0),NoDims)
        #@test isequal(invdimension(1.0u"K"),Symbol(𝚯^-1))
        invdimension(1.0u"K")

        f = 1u"m"
        g = 1 ./ f
        @test dottable(f,g)
        f ⋅ g

        h = 12.0
        j = 1 ./ h
        @test dottable(h,j)
        h ⋅ j
    end
    
    @testset "vectors" begin

        # already implemented in Unitful?
        a = [1u"m", 1u"s", 10u"K"]
        b = [10u"m", -1u"s", 4u"K"]
        a + b
        @test similar(a,b)
        @test a~b
        @test parallel(a,b)
        @test a ∥ b
        #a ⋅ b
        @test ~uniform(b)
        
        c = [1u"m", 1u"s", 10u"K"]
        d = [10u"m^2", -1u"s", 4u"K"]
        @test ~similar(c,d)
        @test ~(c~d)
        @test ~(c∥d)
        #c ⋅ d

        # inverse dimension
        invdimension(a)

        k = 1 ./ a
        a ⋅ k
        @test dottable(a,k)
        @test ~dottable(a,b)
    end

    @testset "matrices" begin
        @testset "heterogeneous" begin
            p = [1.0u"m", 3.0u"s"]
            q̃ = [-1.0u"K", 2.0]

            q = ustrip.(q̃).*unit.(1 ./q̃)
            
            # outer product to make a multipliable matrix
            A = p*q̃'
            B = MultipliableMatrix(ustrip.(A),unit.(p),unit.(q))
            C = expand(B)
            @test A==C

            # test multiplication
            @test isequal(A*q,B*q)
        end

        @testset "column vector" begin
            p = [1.0u"m", 3.0u"s", 5.0u"m/s"]
            q = [-1.0u"K"]
            # outer product to make a multipliable matrix

            # A = column vector
            A = p*q'
            B = MultipliableMatrix(ustrip.(A),unit.(p),unit.( 1 ./q))
            C = expand(B)
            @test A==C
        end

        @testset "nondimensional range" begin
            p = [1.0u"m", 3.0u"s"]
            q = [-1.0, 2.0]
            # outer product to make a multipliable matrix
            A = p*q'
            B = MultipliableMatrix(ustrip.(A),unit.(p),unit.( 1 ./q))
            C = expand(B)
            @test A==C
        end

        @testset "exact" begin
            p = [1.0u"m", 3.0u"s"]
            q̃ = [-1.0u"K", 2.0]

            q = ustrip.(q̃).*unit.(1 ./q̃)
            
            # outer product to make a multipliable matrix
            A = p*q̃'
            B = MultipliableMatrix(ustrip.(A),unit.(p),unit.(q),exact=true)
            C = expand(B)
            @test A==C

            # test multiplication
            @test isequal(A*q,B*q)

            # new domain
            qnew = (q)u"K"
            D = convert_domain(B,unit.(qnew))
            @test B*q ∥ D*qnew

            pnew = (p)u"s"
            qnew = (q)u"s"
            E = convert_range(B,unit.(pnew))
            E*qnew
            @test B*q ∥ E*qnew

            
        end
    end
end
