ENV["UNITFUL_FANCY_EXPONENTS"] = true

using Revise
using UnitfulLinearAlgebra
using Unitful
using LinearAlgebra
using Test

# test/learn from Hart's book

@testset "UnitfulLinearAlgebra.jl" begin
    # Write your tests here.

    m = u"m"
    s = u"s"
    K = u"K"
    m² = u"m^2"

    @testset "scalars" begin
        c = 1m
        d = 2m
        @test c~d
        @test similarity(c,d)
        @test rand() ~ rand()
        @test parallel(rand(),rand())
        @test rand() ∥ rand()
        @test uniform(rand())
        @test uniform((rand())K)
        @test isequal(invdimension(1.0),NoDims)
        #@test isequal(invdimension(1.0K),Symbol(𝚯^-1))
        invdimension(1.0K)

        f = 1m
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
        a = [1m, 1s, 10K]
        b = [10m, -1s, 4K]
        a + b
        @test similarity(a,b)
        @test a~b
        @test parallel(a,b)
        @test a ∥ b
        #a ⋅ b
        @test ~uniform(b)
        
        c = [1m, 1s, 10K]
        d = [10m², -1s, 4K]
        @test ~similarity(c,d)
        @test ~(c~d)
        @test ~(c∥d)
        #c ⋅ d

        # inverse dimension
        invdimension.(a)

        k = 1 ./ a
        a ⋅ k
        @test dottable(a,k)
        @test ~dottable(a,b)
    end

    @testset "matrices" begin

        for i = 1:3
            if i == 1
                p = [1.0m, 9.0s]
                q̃ = [-1.0K, 2.0]
            elseif i == 2
                p = [1.0m, 3.0s, 5.0u"m/s"]
                q̃ = [-1.0K]
            elseif i == 3
                p = [1.0m, 3.0s]
                q̃ = [-1.0, 2.0]
            end
            q = ustrip.(q̃).*unit.(1 ./q̃)
            
            # outer product to make a multipliable matrix
            A = p*q̃'
            B = BestMultipliableMatrix(ustrip.(A),unit.(p),unit.(q),exact=true)

            @test A==Matrix(B)

            # test multiplication
            @test isequal(A*q,B*q)
            @test isequal(uniform(A),uniform(B))
            @test isequal(left_uniform(A),left_uniform(B))
            @test isequal(right_uniform(A),right_uniform(B))
            @test ~dimensionless(B)

        end

        @testset "dimensionless" begin

            # scalar test
            @test dimensionless(1.0)
            @test ~dimensionless(1.0K)
            
            # Not all dimensionless matrices have
            # dimensionless domain and range
            for i = 1:2
                if i == 1
                    p = [1.0m²	, 3.0m²]
                elseif i ==2
                    p = [1.0m², 3.0u"m^3"]
                end
                
                q̃ = [-1.0u"m^-2", 2.0u"m^-2"]
                q = ustrip.(q̃).*unit.(1 ./q̃)
            
                # outer product to make a multipliable matrix
                A = p*q̃'
                B = BestMultipliableMatrix(ustrip.(A),unit.(p),unit.(q))
                if i == 1
                    @test dimensionless(B)
                    @test dimensionless(A)
                elseif i ==2
                    @test ~dimensionless(B)
                    @test ~dimensionless(A)
                end
            end
        end
        
        @testset "exact" begin
            p = [1.0m, 3.0s]
            q̃ = [-1.0K, 2.0]

            q = ustrip.(q̃).*unit.(1 ./q̃)
            
            # outer product to make a multipliable matrix
            A = p*q̃'
            B = BestMultipliableMatrix(ustrip.(A),unit.(p),unit.(q),exact=true)
            Bq = B*q
            @test A==Matrix(B)
            @test isequal(A*q,Bq)
            
            # new domain
            qnew = (q)K
            D = convert_unitdomain(B,unit.(qnew))
            convert_unitdomain!(B,unit.(qnew))
            @test unitrange(D) == unitrange(B)
            @test unitdomain(D) == unitdomain(B)
            @test Bq ∥ D*qnew

            pnew = (p)s
            qnew = (q)s
            E = convert_unitrange(B,unit.(pnew))
            @test Bq ∥ E*qnew
        end

        @testset "array" begin
            p = [1.0m, 3.0s]
            q̃ = [-1.0K, 2.0]
            q = ustrip.(q̃).*unit.(1 ./q̃)
            
            # outer product to make a multipliable matrix
            A = p*q̃'
            B = BestMultipliableMatrix(ustrip.(A),unit.(p),unit.(q),exact=true)

            # turn array into Multipliable matrix
            C = BestMultipliableMatrix(A)
            @test A==Matrix(C)
            @test multipliable(A)
            @test ~left_uniform(A)
            @test isnothing(EndomorphicMatrix(A))
            @test ~endomorphic(C)            
        end

        @testset "endomorphic" begin

            @test endomorphic(1.0)
            @test ~endomorphic(1.0K)
            
            p = [1.0m, 1.0s]
            q̃ = 1 ./ [1.0m, 1.0s]
            q = ustrip.(q̃).*unit.(1 ./q̃)
            
            # outer product to make a multipliable matrix
            A = p*q̃'
            B = BestMultipliableMatrix(A)
            B2 = BestMultipliableMatrix(ustrip.(A),unit.(p),unit.(q))
            B3 = EndomorphicMatrix(ustrip.(A),unit.(p))

            Bᵀ = transpose(B)
            @test Bᵀ[2,1] == B[1,2]

            Ip = EndomorphicMatrix(I(2),[m,s])
            B3 + Ip
            Ip = identitymatrix([m,s])
            
            @test Matrix(B)==Matrix(B2)
            @test Matrix(B3)==Matrix(B2)
            @test multipliable(B)
            @test endomorphic(B2)
            @test endomorphic(B)
            @test endomorphic(A)

            #change domain of B3
            convert_unitrange!(B3,[m²,s*m])
            @test unitrange(B3) == [m²,s*m]

            convert_unitdomain!(B3,[m,s])
            @test unitdomain(B3) == [m,s]
        end

        @testset "squarable" begin
            p = [1.0m, 2.0s]
            q̃ = 1 ./ [2.0m², 3.0m*s]

            q = ustrip.(q̃).*unit.(1 ./q̃)
            
            # outer product to make a multipliable matrix
            A = p*q̃'
            B = BestMultipliableMatrix(ustrip.(A),unit.(p),unit.(q),exact=false)
            @test square(B)
            @test squarable(B)
            B*B
            
            convert_unitrange!(B,K*[m,s])
            @test unitrange(B) == K*[m,s]

            convert_unitdomain!(B,K*[m,s])
            @test unitdomain(B) == K*[m,s]

        end

        @testset "unit symmetric" begin
            p = [2.0m, 1.0s]
            q̃ = p

            p = [m,s]
            q= p.^-1
            
            # outer product to make a multipliable matrix
            A = [1.0 0.1; 0.1 1.0]
            B = BestMultipliableMatrix(A,p,q ,exact=true)
            @test square(B)
            @test ~squarable(B)

            # make equivalent Diagonal matrix.
            C = Diagonal([1.0m, 4.0s],p,q)

            Anodims = ustrip.(A)
            # try cholesky decomposition
            Qnodims = cholesky(Anodims)

            Q = UnitfulLinearAlgebra.cholesky(B)
            test1 = Matrix(transpose(Q.U)*Q.U)
            @test maximum(abs.(ustrip.(B-test1))) < 1e-5

            test2 = Matrix(Q.L*transpose(Q.L))
            @test maximum(abs.(ustrip.(B-test2))) < 1e-5
            @test maximum(abs.(ustrip.(B-Q.L*transpose(Q.L)))) < 1e-5

            # do operations directly with Q?
            Qnodims.U\[0.5, 0.8]
            Q.U\[0.5, 0.8]
            #Q\[0.5, 0.8] # doesn't work
        end

        @testset "matrix * operations" begin
            p = [1.0m, 3.0s]
            q̃ = [-1.0K, 2.0]
            q = ustrip.(q̃).*unit.(1 ./q̃)
            
            # outer product to make a multipliable matrix
            A = p*q̃'
            B = BestMultipliableMatrix(ustrip.(A),unit.(p),unit.(q),exact=true)

            scalar = 2.0K 
            C = B * scalar
            @test (Matrix(C)./Matrix(B))[1,1] == scalar
            C2 = scalar *B
            @test (Matrix(C2)./Matrix(B))[1,1] == scalar

            scalar2 = 5.3
            @test exact(scalar2*B)

            # outer product to make a multipliable matrix
            B2 = MultipliableMatrix(ustrip.(A),unit.(q),unit.(p),exact=true)
            A2 = Matrix(B2)
            
            @test A*A2==Matrix(B*B2)
        end

        @testset "polynomial fitting" begin
           
            u1 = m
            u2 = m/s
            u3 = m/s/s
        
            # example: polynomial fitting
            k = 3
            E = hcat(randn(k),randn(k)u1/u2,randn(k)u1/u3)
            y = randn(k)u1
            x = [randn()u1; randn()u2; randn()u3] 

            Z = lu(ustrip.(E))
            
            F = BestMultipliableMatrix(E)
            
            G = convert_unitdomain(F,unit.(x))

            # doesn't work due to Units type conflict.
            #convert_unitdomain!(G,s.*unit.(x))
            #convert_unitdomain!(G,unit.(x))
            
            Z2 = lu(G)

            # failing with a small error (1e-17)
            @test maximum(abs.(ustrip.(E[Z2.p,:]-Matrix(Z2.L*Z2.U)))) < 1e-5
            @test ~singular(F)
            det(F)

            E⁻¹ = inv(G)

            Eᵀ = transpose(G)
            @test G[2,1] == Eᵀ[1,2]
            #x̃ = E⁻¹ * (E * x) # doesn't work because Vector{Any} in parentheses, dimension() not valid, dimension deprecated?
            y = G*x

            # matrix left divide.
            # just numbers.
            x̃num = ustrip.(E) \ ustrip.(y)

            # an exact matrix
            x̂ = G \ y

            #y2 = convert(Vector{Quantity},y)
            #UnitfulLinearAlgebra.ldiv!(G,y2)
            
            @test abs.(maximum(ustrip.(x̂-x))) < 1e-10

            # an inexact matrix
            x′ = F \ y
            @test abs.(maximum(ustrip.(x′-x))) < 1e-10

            #easy = [1. 0.2; 0.2 1.0]
            #tester = cholesky(easy)
            #@which ldiv!(tester,[2.1,3.1])
            
            x̃ = E⁻¹ * y
            @test abs.(maximum(ustrip.(x̃-x))) < 1e-10

            # Does LU solve the same problem?
            x̆ = Z2 \ y 
            @test abs.(maximum(ustrip.(x̆-x))) < 1e-10

            # works by hand
            𝐱 = Z2.U\(Z2.L\(Z2.P'*y))
            @test abs.(maximum(ustrip.(𝐱-x))) < 1e-10

        end    

        @testset "svd" begin
            
	    E = [1/2 1/2; 1/4 3/4; 3/4 1/4]m
            
            E2 = BestMultipliableMatrix(E)
            @test size(E2)==size(E)
            Eᵀ = transpose(E2)
            @test E2[2,1] == Eᵀ[1,2]

            F = svd(ustrip.(E))
 	    F2 = svd(E2,full=true)
 	    F3 = svd(E2)

            K = length(F3.S)
            G = 0 .*E
            for k = 1:K
                # outer product
                G += F2.S[k] * F2.U[:,k] * transpose(F2.Vt[k,:])
            end
            @test ustrip(abs.(maximum(G- E) )) < 1e-10

            # recover using Diagonal dimensional matrix
            # use Full SVD (thin may not work)
 	    Λ = diagm(F2.S,unitrange(E2),unitdomain(E2),exact=true)
            Ẽ = F2.U*(Λ*F2.Vt)

            @test ustrip(abs.(maximum(Matrix(Ẽ) - E))) < 1e-10
#             K = length(λ) # rank
# 	    y = 5randn(3)u"s"
# 	    σₙ = randn(3)u"s"
# 	    Cₙₙ = diagonal_matrix(σₙ)
# 	    W⁻¹ = diagonal_matrix([1,1,1]u"1/s^2")
# 	    x̃ = inv(E'*W⁻¹*E)*(E'*W⁻¹*y)
# #            [@test isequal(x̃[i]/ustrip(x̃[i]),1.0u"dbar^-1") for i in 1:length(x̃)]

        end
    end
end
