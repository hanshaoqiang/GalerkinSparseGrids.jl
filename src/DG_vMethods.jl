using Cubature
#-------------------------------------------------------------------
# It is sometimes advantageous to have the coeffs as
# one single vector, especially for making use of BLAS
# and related libraries when defining operators on 
# our space of functions
#
# In this script, we "vectorize" our functions,
# not in the regular meaning of the word, but in the
# sense that dictionaries will all be replaced by vectors
#
# The main difficulty with this is that, unlike with dictionaries
# there is no easy way to go from (level, place, fnumber) to a
# corresponding index in a 1-D vector. 
#
# For this, we have the reference functions:
# Full/Sparse Reference V2D/D2V 
# D2V generates a dict that, upon input of a level, place, number
# gives the corresponding index in a vector
# V2D generates a vector, with row i having the three numbers
# level, place, f_number corresponding to index i in the vector
# 
# These methods work in all dimensions, and there are ones for both
# full and sparse grids. 
#
# The entire script culminates in an end result: a matrix 
# representation of the derivative operator 
# (both in full and sparse bases)
#-------------------------------------------------------------------

function sparse_size(k,n,D)
    size=0
    ls = ntuple(i-> (n+1),D)
    for level in CartesianRange(ls) #This really goes from 0 to l_i for each i
        diag_level=0;
        for q in 1:D
            diag_level+=level[q]
        end
        if diag_level > n + D #If we're past the levels we care about, don't compute coeffs
            continue
        end  
        ks = ntuple(q -> 1<<pos(level[q]-2), D)
        size+=prod(ks)*k^D
    end
    return size
end

function Full_D2V{D,T<:Real}(k::Int, coefficients::Dict{CartesianIndex{D}, Array{Array{T},D}}, ls::NTuple{D,Int})
	j=1
	size=0
	f_numbers= ntuple(q-> k, D)
	for level in CartesianRange(ls)
		ks = ntuple(q -> 1<<pos(level[q]-2), D)
		size+=prod(ks)*k^D
	end
	vect = Array(Float64,size)
    for level in CartesianRange(ls)     # This really goes from 0 to l_i for each i,
        ks = ntuple(q -> 1<<pos(level[q]-2), D)  #This sets up a specific k+1 vector
        for place in CartesianRange(ks)
			for f_number in CartesianRange(f_numbers)
                vect[j]=coefficients[level][place][f_number]
				j+=1
            end
        end
    end
	return vect
end

function Sparse_D2V{D,T<:Real}(k::Int, coefficients::Dict{CartesianIndex{D}, Array{Array{T},D}}, n::Int)
	j=1
	size = sparse_size(k,n,D)
	f_numbers= ntuple(i-> k, D)
    ls = ntuple(i->(n+1),D)
	vect = Array(Float64,size)
    for level in CartesianRange(ls) #This really goes from 0 to l_i for each i
        diag_level=0;
        for q in 1:D
            diag_level+=level[q]
        end
        if diag_level > n + D #If we're past the levels we care about, don't compute coeffs
            continue
        end  #Otherwise we'll go ahead and DO IT. The same code follows as before.
	    ks = ntuple(q -> 1<<pos(level[q]-2), D)  #This sets up a specific k+1 vector
	    for place in CartesianRange(ks)
            for f_number in CartesianRange(f_numbers)
                vect[j] = coefficients[level][place][f_number]
				j+=1
            end
        end
    end
    return vect
end



function Full_V2D{D,T<:Real}(k::Int, vect::Array{T}, ls::NTuple{D,Int})
    coeffs = Dict{CartesianIndex{D}, Array{Array{Float64},D}}()
	f_numbers= ntuple(q-> k, D)
	j=1
	for level in CartesianRange(ls)     # This really goes from 0 to l_i for each i,
        ks = ntuple(q -> 1<<pos(level[q]-2), D)  #This sets up a specific k+1 vector
        level_coeffs = Array(Array{Float64},ks)	 #all the coefficients at this level
        for place in CartesianRange(ks)
            level_coeffs[place]=Array(Float64,f_numbers)
			for f_number in CartesianRange(f_numbers)
                level_coeffs[place][f_number]=vect[j]
				j+=1
            end
        end
		coeffs[level] = level_coeffs
    end
	return coeffs
end

function Sparse_V2D{T<:Real}(k::Int, vect::Array{T}, n::Int, D::Int)
    coeffs = Dict{CartesianIndex{D}, Array{Array{Float64},D}}()
	f_numbers= ntuple(q-> k, D)
    ls = ntuple(i->(n+1),D)
	j=1
	for level in CartesianRange(ls) #This really goes from 0 to l_i for each i
        diag_level=0;
        for q in 1:D
            diag_level+=level[q]
        end
        if diag_level > n + D #If we're past the levels we care about, don't compute coeffs
            continue
        end  
		#Otherwise we'll go ahead and DO IT. The same code follows as before.
        ks = ntuple(q -> 1<<pos(level[q]-2), D)  #This sets up a specific k+1 vector
        level_coeffs = Array(Array{Float64},ks)	 #all the coefficients at this level
        for place in CartesianRange(ks)
            level_coeffs[place]=Array(Float64,f_numbers)
			for f_number in CartesianRange(f_numbers)
                level_coeffs[place][f_number]=vect[j]
				j+=1
            end
        end
		coeffs[level] = level_coeffs
    end
	return coeffs
end



function full_referenceD2V{D}(k::Int, ls::NTuple{D,Int})
	j=1
	size=0
	f_numbers= ntuple(q-> k, D)
	dict = Dict{Array{CartesianIndex{D},1},Int}()
    for level in CartesianRange(ls)
        ks = ntuple(q -> 1<<pos(level[q]-2), D)  #This sets up a specific k+1 vector
		lvl = ntuple(i -> level[i]-1,D)
        for place in CartesianRange(ks)
			for f_number in CartesianRange(f_numbers)
                dict[[level,place,f_number]] = j
				j+=1
            end
        end
    end
	return dict
end

function full_referenceV2D{D}(k::Int, ls::NTuple{D,Int})
	j=1
	size=0
	f_numbers= ntuple(q-> k, D)
	for level in CartesianRange(ls)
		ks = ntuple(q -> 1<<pos(level[q]-2), D)
		size+=prod(ks)*k^D
	end
	vect = Array(CartesianIndex{D},(size,3))
    for level in CartesianRange(ls)
        ks = ntuple(q -> 1<<pos(level[q]-2), D)  #This sets up a specific k+1 vector
		lvl = ntuple(i -> level[i]-1,D)
        for place in CartesianRange(ks)
			for f_number in CartesianRange(f_numbers)
                vect[j,1]=level
				vect[j,2]=place
				vect[j,3]=f_number
				j+=1
            end
        end
    end
	return vect
end

function sparse_referenceD2V(k::Int,n::Int,D::Int)
	j=1
	f_numbers= ntuple(q-> k, D)
	size=sparse_size(k,n,D)
	dict = Dict{Array{CartesianIndex{D},1},Int}()
    ls = ntuple(i->(n+1),D)
    for level in CartesianRange(ls)
        diag_level=0;
        for q in 1:D
            diag_level+=level[q]
        end
        if diag_level > n + D #If we're past the levels we care about, don't compute coeffs
            continue
		end
        ks = ntuple(q -> 1<<pos(level[q]-2), D)  #This sets up a specific k+1 vector
		lvl = ntuple(i -> level[i]-1,D)
        for place in CartesianRange(ks)
			for f_number in CartesianRange(f_numbers)
                dict[[level,place,f_number]] = j
				j+=1
            end
        end
    end
	return dict
end

function sparse_referenceV2D(k::Int,n::Int,D::Int)
	j=1
	f_numbers= ntuple(q-> k, D)
	size=sparse_size(k,n,D)
	vect = Array(CartesianIndex{D},(size,3))
    ls = ntuple(i->(n+1),D)
    for level in CartesianRange(ls)
        diag_level=0;
        for q in 1:D
            diag_level+=level[q]
        end
        if diag_level > n + D #If we're past the levels we care about, don't compute coeffs
            continue
		end
        ks = ntuple(q -> 1<<pos(level[q]-2), D)  #This sets up a specific k+1 vector
		lvl = ntuple(i -> level[i]-1,D)
        for place in CartesianRange(ks)
			for f_number in CartesianRange(f_numbers)
                vect[j,1]=level
				vect[j,2]=place
				vect[j,3]=f_number
				j+=1
            end
        end
    end
	return vect
end


#------------------------------------------------------
# Let's now make the coefficient operators work on
# and return vectors
#------------------------------------------------------

function vhier_coefficients_DG{D}(k::Int, f::Function, ls::NTuple{D,Int};
							rel_tol = REL_TOL, abs_tol = ABS_TOL, max_evals=MAX_EVALS)
 	l = k^D * 2^(sum(ls)-D)
    coeffs = Array(Float64, l)
	f_numbers= ntuple(i-> k, D)
	j=1
    for level in CartesianRange(ls)     # This really goes from 0 to l_i for each i,
        ks = ntuple(i -> 1<<pos(level[i]-2), D)  #This sets up a specific k+1 vector
		lvl = ntuple(i -> level[i]-1,D)
        for place in CartesianRange(ks)
			for f_number in CartesianRange(f_numbers)
                coeffs[j]=get_coefficient_DG(k,f,lvl,place,f_number;
									rel_tol = rel_tol, abs_tol=abs_tol, max_evals=max_evals)
				j+=1          
            end
        end
    end
    return coeffs
end



function vsparse_coefficients_DG(k::Int, f::Function, n::Int, D::Int;
								rel_tol = REL_TOL, abs_tol = ABS_TOL, max_evals=MAX_EVALS)
 	len = sparse_size(k,n,D)
    coeffs = Array(Float64, len)
	f_numbers= ntuple(i-> k, D)
	ls = ntuple(i-> (n+1),D)
	j=1
    for level in CartesianRange(ls)     # This really goes from 0 to l_i for each i,
        diag_level=0;
        for q in 1:D
            diag_level+=level[q]
        end
        if diag_level > n + D #If we're past the levels we care about, don't compute coeffs
            continue
        end  
        ks = ntuple(i -> 1<<pos(level[i]-2), D)  #This sets up a specific k+1 vector
		lvl = ntuple(i -> level[i]-1,D)
        for place in CartesianRange(ks)
			for f_number in CartesianRange(f_numbers)
                coeffs[j]=get_coefficient_DG(k,f,lvl,place,f_number;
									rel_tol = rel_tol, abs_tol=abs_tol, max_evals=max_evals)
				j+=1          
            end
        end
    end
    return coeffs
end



# You may want to implement fullreconstruct and sparsereconstruct

# ------------------------------------------------------
# And now here's the point of doing all of this:
# efficiently computing a size P log P matrix
# to represent the derivative operator
# ------------------------------------------------------

function sD_matrix{D}(i::Int, k::Int,
    srefVD::Array{CartesianIndex{D},2}, srefDV::Dict{Array{CartesianIndex{D},1},Int})
    len = length(srefVD[:,1])
    sMat= spzeros(len,len)
	f_numbers= ntuple(i-> k, D)
    for c1 in 1:len
        lpf = slice(srefVD,c1,:)
        p = lpf[2][i]
        for level in (lpf[1][i]):-1:1
            level2= CartesianIndex{D}(ntuple(j-> j==i?level:(lpf[1][j]) , D))
            place2= CartesianIndex{D}(ntuple(j-> j==i?p:(lpf[2][j]) ,D))
            for f_n in 1:k
                f_number2= CartesianIndex{D}(ntuple(j-> j==i?f_n:lpf[3][j] ,D))
                c2 = srefDV[[level2,place2,f_number2]]
                sMat[c2,c1] += precomputed_diffs[(k,lpf[1][i]-1,lpf[2][i],lpf[3][i])][level,f_n]
            end
            p = Int(ceil(p/2))
        end
    end
    return sMat
end

