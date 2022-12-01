module UnitfulLinearAlgebra

using Unitful, LinearAlgebra, SparseArrays

export MultipliableMatrix, EndomorphicMatrix
export SquarableMatrix, UniformMatrix
export BestMultipliableMatrix
export similarity, ∥, parallel
export uniform, left_uniform, right_uniform
export invdimension, dottable
export getindex, setindex!, size
export convert_unitrange, convert_unitdomain
#export convert_range!, convert_domain!
export exact, multipliable, dimensionless, endomorphic
export svd, inv, transpose
export unitrange, unitdomain
export square, squarable, singular
export lu, det, diagm, (\)
export identitymatrix

import LinearAlgebra: inv, det, lu, svd, getproperty,
    diagm
import Base:(~), (*), (+), (\), getindex, setindex!,
    size, range, transpose
#import Base.similar

abstract type MultipliableMatrices{T<:Number} <: AbstractMatrix{T} end

"""
    struct MultipliableMatrix

    Matrices with units that a physically reasonable,
    i.e., more than just an array of values with units.

    Multipliable matrices have dimensions that are consistent with many linear algebraic manipulations, including multiplication.

    Hart suggests that these matrices simply be called "matrices", and that matrices with dimensional values that cannot be multiplied should be called "arrays."

# Attributes
- `numbers`: numerical (dimensionless) matrix
- `unitrange`: dimensional range in terms of units
- `unitdomain`: dimensional domain in terms of units
- `exact`: geometric (`true`) or algebraic (`false`) interpretation
"""
struct MultipliableMatrix{T <:Number} <: MultipliableMatrices{T}
    numbers::AbstractMatrix{T}
    unitrange::Vector
    unitdomain::Vector
    exact::Bool
end

"""
    struct EndomorphicMatrix

    An endomorphic matrix maps a dimensioned vector space
    to itself. The dimensional range and domain are the same.

# Attributes
- `numbers`: numerical (dimensionless) matrix
- `unitrange`: dimensional range in terms of units, and also equal the dimensional domain
- `exact`: geometric (`true`) or algebraic (`false`) interpretation
"""
struct EndomorphicMatrix{T<:Number} <: MultipliableMatrices{T} 
    numbers::AbstractMatrix{T}
    unitrange::Vector
    exact::Bool
end

"""
    struct SquarableMatrix

    An squarable matrix is one where 𝐀² is defined.
    It is the case if the dimensional range and domain are parallel.

# Attributes
- `numbers`: numerical (dimensionless) matrix
- `unitrange`: dimensional range in terms of units, this is also the domain
- `Δunitdomain`: shift to range that gives the domain
- `exact`: geometric (`true`) or algebraic (`false`) interpretation
"""
struct SquarableMatrix{T<:Number} <: MultipliableMatrices{T} 
    numbers::AbstractMatrix{T}
    unitrange::Vector
    Δunitdomain
    exact::Bool
end

"""
    struct UniformMatrix

    Uniform matrix

# Attributes
- `numbers`: numerical (dimensionless) matrix
- `unitrange`:  uniform dimensional range expressed as a single unit
- `unitdomain`: uniform dimensional domain expressed as a single unit
- `exact`: geometric (`true`) or algebraic (`false`) interpretation
"""
struct UniformMatrix{T<:Number} <: MultipliableMatrices{T}
    numbers::AbstractMatrix{T}
    unitrange
    unitdomain
    exact::Bool
end
# struct UniformMatrix{T,R,D} <: MultipliableMatrices where {T <: Number} where {R,D <: Unitful.Unitlike}
#     numbers::Matrix{T}
#     range::R
#     domain::D
#     exact::Bool
# end

"""
    MultipliableMatrix(numbers,unitrange,unitdomain;exact=false)

    Constructor where `exact` is a keyword argument. One may construct a MultipliableMatrix without specifying exact, in which case it defaults to `false`. 
"""
MultipliableMatrix(numbers,unitrange,unitdomain;exact=false) =
    MultipliableMatrix(numbers,unitrange,unitdomain,exact)

"""
     BestMultipliableMatrix(A::Matrix)

    Transform array to a type <: MultipliableMatrices.
    Finds best representation amongst
    UniformMatrix, EndomorphicMatrix, or MultipliableMatrix.
    Assumes `exact=false`
"""
function BestMultipliableMatrix(A::Matrix)

    numbers = ustrip.(A)
    M,N = size(numbers)
    #U = typeof(unit(A[1,1]))
    #U = eltype(unit.(A))
    # unitdomain = Vector{U}(undef,N)
    # unitrange = Vector{U}(undef,M)
    unitdomain = Vector{Unitful.FreeUnits}(undef,N)
    unitrange = Vector{Unitful.FreeUnits}(undef,M)

    for i = 1:M
        unitrange[i] = unit(A[i,1])
    end
    
    for j = 1:N
        unitdomain[j] = unit(A[1,1])/unit(A[1,j])
    end

    B = BestMultipliableMatrix(numbers,unitrange,unitdomain)
    # if the array is not multipliable, return nothing
    if Matrix(B) == A
        return B
    else
        return nothing
    end
end

"""
    function BestMultipliableMatrix(numbers,unitrange,unitdomain;exact=false)

    What kind of Multipliable Matrix is the best representation?
"""
function BestMultipliableMatrix(numbers::AbstractMatrix,unitrange::AbstractVector,unitdomain::AbstractVector;exact=false)
    if uniform(unitrange) && uniform(unitdomain)
        B = UniformMatrix(numbers,unitrange[1],unitdomain[1],exact)
    elseif unitrange == unitdomain
        B = EndomorphicMatrix(numbers,unitrange,exact)
    elseif unitrange ∥ unitdomain
        Δunitdomain = unitdomain[1]./unitrange[1]
        B = SquarableMatrix(numbers,unitrange,Δunitdomain,exact)
    else
        B = MultipliableMatrix(numbers,unitrange,unitdomain,exact)
    end
end

"""
    function multipliable(A)::Bool

    Is an array multipliable?
    It requires a particular structure of the units/dimensions in the array. 
"""
multipliable(A::Matrix) = ~isnothing(BestMultipliableMatrix(A))
multipliable(A::T) where T <: MultipliableMatrices = true

"""
    function EndomorphicMatrix

    Constructor with keyword argument `exact=false`.
    If `exact` not specified, defaults to `false`.
"""
EndomorphicMatrix(numbers,unitrange;exact=false) =
    EndomorphicMatrix(numbers,unitrange,exact)

"""
     EndomorphicMatrix(A)

    Transform array to EndomorphicMatrix type
"""
function EndomorphicMatrix(A::Matrix)

    numbers = ustrip.(A)
    M,N = size(numbers)

    # must be square
    if M ≠ N
        return nothing
    end
    
    unitrange = Vector{Unitful.FreeUnits}(undef,M)
    for i = 1:M
        unitrange[i] = unit(A[i,1])
    end
    B = EndomorphicMatrix(numbers,unitrange)
    
    # if the array is not multipliable, return nothing
    if Matrix(B) == A
        return B
    else
        return nothing
    end
end

"""
    function EndomorphicMatrix(A::T) where T <: Number

    Special case of a scalar. Must be dimensionless.
"""
function EndomorphicMatrix(A::T) where T <: Number
    if dimensionless(A)
        numbers = Matrix{T}(undef,1,1)
        numbers[1,1] = A

        unitrange = Vector{Unitful.FreeUnits}(undef,1)
        unitrange[1] = unit(A)
        return EndomorphicMatrix(numbers,unitrange)
    else
        return nothing
    end
end


"""
    function endomorphic(A)::Bool

    Endomorphic matrices have a particular structure
     of the units/dimensions in the array. 
"""
endomorphic(A::Matrix) = ~isnothing(EndomorphicMatrix(A))
endomorphic(A::EndomorphicMatrix) = true
endomorphic(A::T) where T <: MultipliableMatrices = isequal(unitdomain(A),unitrange(A))
endomorphic(A::T) where T <: Number = dimensionless(A) # scalars must be dimensionless to be endomorphic

"""
    function UniformMatrix

    Constructor with keyword argument `exact=false`.
    If `exact` not specified, defaults to `false`.
"""
UniformMatrix(numbers,unitrange,unitdomain;exact=false) =
    UniformMatrix(numbers,unitrange,unitdomain,exact)

"""
    function getindex(A::MultipliableMatrix,i::Integer,j::Integer)

    Recover element (i,j) of a MultipliableMatrix.
    Part of the AbstractArray interface.
#Input
- `A::MultipliableMatrix`
- `i::Integer`: row index
- `j::Integer`: column index
#Output
- `Quantity`: numerical value and units
"""
getindex(A::T,i::Int,j::Int) where T <: MultipliableMatrices = Quantity(A.numbers[i,j],unitrange(A)[i]./unitdomain(A)[j]) 

"""
    function setindex!(A::MultipliableMatrix,v,i,j)

    Set element (i,j) of a MultipliableMatrix.
    Part of the AbstractArray interface.
#Input
- `A::MultipliableMatrix`
- `v`: new value
- `i::Integer`: row index
- `j::Integer`: column index
#Output
- `Quantity`: numerical value and units
"""
setindex!(A::T,v,i::Int,j::Int) where T <: MultipliableMatrices = (unit(v) == unitrange(A)[i]./unitdomain(A)[j]) ? (A.numbers[i,j] = ustrip(v)) : error("new value has incompatible units")

"""
    function Matrix(A::MultipliableMatrix)

    Expand A into array form
    Useful for tests, display
    pp. 193, Hart
"""
function Matrix(A::T) where T<: MultipliableMatrices

    M = rangelength(A)
    N = domainlength(A)
    T2 = eltype(A.numbers)
    B = Matrix{Quantity{T2}}(undef,M,N)
    for m = 1:M
        for n = 1:N
            B[m,n] = getindex(A,m,n)
        end
    end
    return B
end

# """
#     function convert(AbstractMatrix,A::MultipliableMatrix)

#     Expand A into array form
#     Useful for tests, display
#     pp. 193, Hart
# """
# function convert(AbstractMatrix{T},A::MultipliableMatrices)  where T<: Number

#     M = rangelength(A)
#     N = domainlength(A)
#     T2 = eltype(A.numbers)
#     B = Matrix{Quantity{T2}}(undef,M,N)
#     for m = 1:M
#         for n = 1:N
#             B[m,n] = getindex(A,m,n)
#         end
#     end
#     return B
# end

"""
    function *(A::MultipliableMatrices,b)

    Matrix-vector multiplication with units/dimensions.
    Unitful also handles this case, but here there is added
    efficiency in the storage of units/dimensions by accounting
    for the necessary structure of the matrix.
"""
function *(A::T,b::Vector) where T<: MultipliableMatrices

    if dimension(unitdomain(A)) == dimension(b)
    #if unitdomain(A) ~ b
        return (A.numbers*ustrip.(b)).*A.unitrange
    elseif ~exact(A) && (unitdomain(A) ∥ b)
        Anew = convert_unitdomain(A,b) # inefficient?
        return (Anew.numbers*ustrip.(b)).*Anew.unitrange
    else
        error("Dimensions of MultipliableMatrix and vector not compatible")
    end
end

"""
    function *(A::MultipliableMatrix,b)

    Matrix-scalar multiplication with units/dimensions.
    Must account for change in the unitrange when the
     scalar has units.
    Here, take product of dimension of the scalar and the unitrange.
    Alternatively, divide the domain by the dimension of the scalar. 
    Matrix-scalar multiplication is commutative.
    Result is `exact` if input matrix is exact and scalar is dimensionless. 
    Note: special matrix forms revert to a product that is a MultipliableMatrix.
"""
*(A::T1,b::T2) where T1 <: MultipliableMatrices where T2 <: Number = (exact(A) && dimensionless(b)) ?  BestMultipliableMatrix(A.numbers*ustrip(b),unitrange(A).*unit(b),unitdomain(A),exact = true) : BestMultipliableMatrix(A.numbers*ustrip(b),unitrange(A).*unit(b),unitdomain(A))
*(b::T2,A::T1) where T1 <: MultipliableMatrices where T2 <: Number = A*b

"""
    function *(A,B)

    Matrix-matrix multiplication with units/dimensions.
    A*B represents two successive transformations.
    Unitrange of B should equal domain of A in geometric interpretation.
    Unitrange of B should be parallel to unitdomain of A in algebraic interpretation.

    Note: special matrix forms revert to a product that is a MultipliableMatrix.
"""
function *(A::T1,B::T2) where T1<:MultipliableMatrices where T2<:MultipliableMatrices
    #if unitrange(B) ~ unitdomain(A) # should this be similarity()?

    exactproduct = exact(A) && exact(B)
    if unitrange(B) == unitdomain(A) # should this be similarity()?
        return BestMultipliableMatrix(A.numbers*B.numbers,unitrange(A),unitdomain(B),exact=exactproduct) 
    elseif unitrange(B) ∥ unitdomain(A) && ~exactproduct
        A2 = convert_unitdomain(A,unitrange(B)) 
        return BestMultipliableMatrix(A2.numbers*B.numbers,unitrange(A2),unitdomain(B),exact=exactproduct)
    else
        error("matrix dimensional domain/unitrange not conformable")
    end
end

# special case: MultipliableMatrix * non-multipliable matrix
*(A::T1,B::T2) where T1<:MultipliableMatrices where T2<:AbstractMatrix = A*BestMultipliableMatrix(B)
*(A::T2,B::T1) where T1<:MultipliableMatrices where T2<:AbstractMatrix = BestMultipliableMatrix(A)*B

"""
    function +(A,B)

    Matrix-matrix addition with units/dimensions.
    A+B requires the two matrices to have dimensional similarity.
"""
function +(A::MultipliableMatrices{T1},B::MultipliableMatrices{T2}) where T1 where T2

    #if unitrange(A) ~ unitrange(B) && unitdomain(A) ~ unitdomain(B)
    if unitrange(A) == unitrange(B) && unitdomain(A) == unitdomain(B)
        exactproduct = exact(A) && exact(B)
        return MultipliableMatrix(A.numbers+B.numbers,unitrange(A),unitdomain(A),exact=exactproduct) 
    else
        error("matrices not dimensionally conformable for addition")
    end
end

"""
    function lu(A::MultipliableMatrices{T})

    Extend `lu` factorization to MultipliableMatrices.
    Related to Gaussian elimination.
    Store dimensional domain and range in "factors" attribute
    even though this is not truly a MultipliableMatrix.
    Returns `LU` type in analogy with `lu` for unitless matrices.
    Based on LDU factorization, Hart, pp. 204.
"""
function lu(A::MultipliableMatrices{T}) where T <: Number
    #where T <: MultipliableMatrices

    F̂ = lu(A.numbers)

    factors = MultipliableMatrix(F̂.factors,unitrange(A),unitdomain(A),exact(A))
    F = LU(factors,F̂.ipiv,F̂.info)
    return F
end

"""
    function getproperty(F::LU{T,<:MultipliableMatrices,Vector{Int64}}, d::Symbol) where T

    Extend LinearAlgebra.getproperty for MultipliableMatrices.

    LU factorization stores L and U together.
    Extract L and U while keeping consistent
    with dimensional domain and range.
"""
function getproperty(F::LU{T,<:MultipliableMatrices,Vector{Int64}}, d::Symbol) where T
    m, n = size(F)
    if d === :L
        mmatrix = getfield(F, :factors)
        numbers = getfield(mmatrix,:numbers)
        # add ustrip to get numerical values
        Lnum = tril!(numbers[1:m, 1:min(m,n)])
        for i = 1:min(m,n); Lnum[i,i] = one(T); end
        L = EndomorphicMatrix(Lnum,unitrange(mmatrix),exact(mmatrix))
        return L
    elseif d === :U
        mmatrix = getfield(F, :factors)
        numbers = getfield(mmatrix,:numbers)
        Unum = triu!(numbers[1:min(m,n), 1:n])
        U = MultipliableMatrix(Unum, unitrange(mmatrix), unitdomain(mmatrix), exact(mmatrix))
        return U
    elseif d === :p
        return LinearAlgebra.ipiv2perm(getfield(F, :ipiv), m)
    elseif d === :P
        return Matrix{T}(I, m, m)[:,LinearAlgebra.invperm(F.p)]
    else
        getfield(F, d)
    end
end

"""
    function similarity(a,b)::Bool

    Dimensional similarity of vectors, a binary relation
    Read "a has the same dimensional form as b"
    `a` and `b` may still have different units.
    A stronger condition than being parallel.
    pp. 184, Hart
"""
 similarity(a,b)::Bool = isequal(dimension(a),dimension(b))
 ~(a,b) = similarity(a,b)
#similarity(a,b) = isequal(dimension

"""
    function parallel

    Vector a is dimensionally parallel to vector b if
    they have the same length and a consistent dimensional
    change relates corresponding components.
    Guaranteed if two vectors are dimensionally similar.
    True for scalars in all cases. 

    pp. 188, Hart
    Note: Hart uses ≈, but this conflicts with an existing Julia function.
"""
function parallel(a,b)::Bool

    if isequal(length(a),length(b))
        if length(a) == 1
            return true
        else
            Δdim = dimension(a)./dimension(b)
            for i = 2:length(a)
                if Δdim[i] ≠ Δdim[1]
                    return false
                end
            end
            return true
        end
    else
        return false
    end
end
∥(a,b)  = parallel(a,b)

"""
    function uniform(a)

    Is the dimension of this quantity uniform?

    There must be a way to inspect the Unitful type to answer this.
"""
uniform(a::T) where T <: Number = true # all scalars by default
function uniform(a::Vector) 
    dima = dimension(a)
    for dd = 2:length(dima)
        if dima[dd] ≠ dima[1]
            return false
        end
    end
    return true
end
function uniform(A::Matrix)
    B = BestMultipliableMatrix(A)
    isnothing(B) ? false : uniform(B)
end
uniform(A::T) where T <: MultipliableMatrices = left_uniform(A) && right_uniform(A)
uniform(A::UniformMatrix) = true

"""
    function left_uniform(A)

    Does the unitrange of A have uniform dimensions?
"""
left_uniform(A::T) where T<: MultipliableMatrices = uniform(unitrange(A)) ? true : false
function left_uniform(A::Matrix)
    B = BestMultipliableMatrix(A)
    isnothing(B) ? false : left_uniform(B)
end

"""
    function right_uniform(A)

    Does the unitdomain of A have uniform dimensions?
"""
right_uniform(A::T) where T<:MultipliableMatrices = uniform(unitdomain(A)) ? true : false
function right_uniform(A::Matrix)
    B = BestMultipliableMatrix(A)
    isnothing(B) ? false : right_uniform(B)
end

"""
     function dimensionless(A)

     Not all dimensionless matrices have
     dimensionless domain and range.
"""
dimensionless(A::T) where T <: MultipliableMatrices = uniform(A) && unitrange(A)[1] == unitdomain(A)[1]
dimensionless(A::Matrix) = uniform(A) && dimension(A[1,1]) == NoDims
dimensionless(A::T) where T <: Number = (dimension(A) == NoDims)

square(A::T) where T <: MultipliableMatrices = (domainlength(A) == rangelength(A))

squarable(A::T) where T <: MultipliableMatrices = (unitdomain(A) ∥ unitrange(A))

"""
    function invdimension

    Dimensional inverse
      
    pp. 64, Hart, `a~` in his notation
"""
invdimension(a) = dimension(1 ./ a)

"""
    function dottable(a,b)

    Are two quantities dimensionally compatible
    to take a dot product?
"""
dottable(a,b) = parallel(a, 1 ./ b)

"""
    function convert_unitdomain(A, newdomain)

    When using the geometric interpretation of matrices,
    it is useful to convert the dimensional domain of the
    matrix to match the expected vectors during multiplication.
    Here we set the matrix to `exact=true` after this step.
"""
function convert_unitdomain(A::T, newdomain::Vector) where T<:MultipliableMatrices
    if unitdomain(A) ∥ newdomain
        shift = newdomain./unitdomain(A)
        newrange = unitrange(A).*shift
        B = BestMultipliableMatrix(A.numbers,newrange,newdomain,exact=true)
    else
        error("New unitdomain not parallel to unitdomain of Multipliable Matrix")
    end
end

#ERROR: setfield!: immutable struct of type MultipliableMatrix cannot be changed
# function convert_domain!(A::MultipliableMatrix, newdomain::Vector)::MultipliableMatrix
#     if A.domain ∥ newdomain
#         shift = newdomain./A.domain
#         newrange = A.range.*shift
#         A.domain = newdomain
#         A.range = newrange
#     else
#         error("New domain not parallel to domain of Multipliable Matrix")
#     end
# end

"""
    function convert_unitrange(A, newrange)

    When using the geometric interpretation of matrices,
    it is useful to convert the dimensional range of the
    matrix to match the desired output of multiplication.
    Here we set the matrix to `exact=true` after this step.
"""
function convert_unitrange(A::MultipliableMatrix, newrange::Vector)::MultipliableMatrix
    if unitrange(A) ∥ newrange
        shift = newrange./unitrange(A)
        newdomain = unitdomain(A).*shift
        B = MultipliableMatrix(A.numbers,newrange,newdomain,exact=true)
    else
        error("New unitrange not parallel to unitrange of Multipliable Matrix")
    end
end

#ERROR: setfield!: immutable struct of type MultipliableMatrix cannot be changed
# function convert_range!(A::MultipliableMatrix, newrange::Vector)::MultipliableMatrix
#     if A.range ∥ newrange
#         shift = newrange./A.range
#         newdomain = A.domain.*shift
#         A = MultipliableMatrix(A.numbers,newrange,newdomain,A.exact)
#     else
#         error("New range not parallel to range of Multipliable Matrix")
#     end
# end

"""
    function exact(A)

-    `exact=true`: geometric interpretation of unitdomain and unitrange
-    `exact=false`: algebraic interpretation
"""
exact(A::T) where T <: MultipliableMatrices = A.exact

"""
    function rangelength(A::MultipliableMatrix)

    Numerical dimension (length or size) of unitrange
"""
rangelength(A::T) where T <: MultipliableMatrices = length(unitrange(A))

"""
    function domainlength(A::MultipliableMatrix)

    Numerical dimension (length or size) of unitdomain of A
"""
domainlength(A::T) where T <: MultipliableMatrices = length(unitdomain(A))

size(A::MultipliableMatrices) = (rangelength(A), domainlength(A))

convert(::Type{AbstractMatrix{T}}, A::MultipliableMatrices) where {T<:Number} = convert(MultipliableMatrices{T}, A)
convert(::Type{AbstractArray{T}}, A::MultipliableMatrices) where {T<:Number} = convert(MultipliableMatrices{T}, A)
#convert(::Type{AbstractArray{T}}, S::AbstractToeplitz) where {T<:Number} = convert(AbstractToeplitz{T}, S)

unitdomain(A::T) where T <: MultipliableMatrices = A.unitdomain
unitdomain(A::SquarableMatrix) = A.unitrange.*A.Δunitdomain
unitdomain(A::EndomorphicMatrix) = A.unitrange # unitdomain not saved and must be reconstructed
unitdomain(A::UniformMatrix) = fill(A.unitdomain,size(A.numbers)[2])

unitrange(A::T) where T <: MultipliableMatrices = A.unitrange
unitrange(A::UniformMatrix) = fill(A.unitrange,size(A.numbers)[1])

"""
    function transpose

    Defined by condition `A[i,j] = transpose(A)[j,i]`.
    Not analogous to function for dimensionless matrices.

    Hart, pp. 205.
"""
transpose(A::MultipliableMatrices) = MultipliableMatrix(transpose(A.numbers),unit.(1 ./unitdomain(A)), unit.(1 ./unitrange(A)),exact(A)) 
transpose(A::EndomorphicMatrix{T}) where T = EndomorphicMatrix(transpose(A.numbers),unit.(1 ./unitrange(A)), exact(A)) 
transpose(A::UniformMatrix) = UniformMatrix(transpose(A.numbers),unit.(1 ./unitdomain(A)[1]), unit.(1 ./unitrange(A)[1]), exact(A)) 

"""
    function identitymatrix(dimrange)

    Input: dimensional (unit) range.
    `A + I` only defined when `endomorphic(A)=true`
    When accounting for units, there are many identity matrices.
    This function returns a particular identity matrix
    defined by its dimensional range.
    Hart, pp. 200.                             
"""
identitymatrix(dimrange) = EndomorphicMatrix(I(length(dimrange)),dimrange;exact=false)

"""
     function inv

     Inverse of Multipliable Matrix.
     Only defined for nonsingular matrices.
     Inverse reverses mapping from unitdomain to range.
     Is `exact` if input is exact.

    Hart, pp. 205. 
"""
inv(A::T) where T <: MultipliableMatrices = ~singular(A) ? BestMultipliableMatrix(inv(A.numbers),unitdomain(A),unitrange(A),exact=exact(A)) : error("matrix is singular")

"""
     function ldiv!

     Left divide of Multipliable Matrix.
     Reverse mapping from unitdomain to range.
     Is `exact` if input is exact.
"""
function (\)(A::MultipliableMatrices,b::AbstractVector)

    # unit.(range(b)) == range(A) ?  BestMultipliableMatrix(A.numbers\ustrip.(b),unitdomain(A),range(A),exact(A)) : error("matrix and vector units don't match")
    if dimension(unitrange(A)) == dimension(b)
    #if unitrange(A) ~ b
        return (A.numbers\ustrip.(b)).*unitdomain(A)
    elseif ~exact(A) && (unitrange(A) ∥ b)
        Anew = convert_unitrange(A,unit.(b)) # inefficient?
        return (Anew.numbers\ustrip.(b)).*unitdomain(Anew)
    else
        error("UnitfulLinearAlgebra.mldivide: Dimensions of MultipliableMatrix and vector not compatible")
    end
end

"""
    function det
"""
function det(A::T) where T<: MultipliableMatrices

    if square(A)
        # detunit = Vector{eltype(domain(A))}(undef,domainlength(A))
        # for i = 1:domainlength(A)
        # end
        detunit = prod([unitrange(A)[i]/unitdomain(A)[i] for i = 1:domainlength(A)])

        return Quantity(det(A.numbers),detunit)
    else
        error("Determinant requires square matrix")
    end
end

singular(A::T) where T <: MultipliableMatrices = iszero(ustrip(det(A)))

"""
    svd(A; full::Bool = false, alg::Algorithm = default_svd_alg(A)) -> SVD

Compute the singular value decomposition (SVD) of `A` and return an `SVD` object. Extended for MultipliableMatrix input.
"""
#function svd(A::MultipliableMatrices;full=false) where T <: MultipliableMatrices
function svd(A::MultipliableMatrices;full=false,alg::LinearAlgebra.Algorithm = LinearAlgebra.default_svd_alg(A.numbers)) 
    if uniform(A) 
        F = svd(A.numbers, full=full, alg=alg)
        # U,V just regular matrices: return that way?
        # They are also Uniform and Endomorphic
        return SVD(F.U,F.S * unitrange(A)[1]./unitdomain(A)[1],F.Vt)
    else
        error("SVD not implemented for non-uniform matrices or non-full flag")
    end
end

"""
    function Diagonal(v::AbstractVector,r::Unitful.Unitlike,d::Unitful.Unitlike; exact = false)

    Construct Diagonal matrix with units where the diagonal has elements `v`.

    If `v` has units, check that they conform with dimensional range `r` and dimensional domain `d`.

    `LinearAlgebra.Diagonal` produces a square diagonal matrix. Instead, this is based upon `spdiagm`. 
"""
diagm(v::AbstractVector,r::AbstractVector,d::AbstractVector; exact = false) = BestMultipliableMatrix(spdiagm(length(r),length(d),ustrip.(v)),r,d; exact=exact)    
#Diagonal(v::AbstractVector,r::Unitful.Unitlike,d::Unitful.Unitlike; exact = false) = MultipliableMatrix(Diagonal(ustrip.(v)),r,d ; exact=exact)    
#end

end
