### A Pluto.jl notebook ###
# v0.19.25

using Markdown
using InteractiveUtils

# ╔═╡ 6f92c837-1760-423e-9777-9db9ad758475
using PlutoUI

# ╔═╡ 563c267e-0c6a-4b90-81a7-fc8ff4c73c75
using AlgebraOfGraphics, CairoMakie

# ╔═╡ 6d5523f2-a517-48df-9f31-bbd516e1208e
using Parameters

# ╔═╡ 9fa33ac0-bb2f-4055-b124-8c7c19621226
using LinearAlgebra

# ╔═╡ 276e171b-271d-4610-b9bb-01b212193123
using SparseArrays

# ╔═╡ aecea3fe-f0ee-4953-857b-29d6a5640530
using DataFrames

# ╔═╡ 9353566b-a70e-4dbe-8f02-b16d2c0570d2
using Chain: @chain

# ╔═╡ 0b9c3978-0eb9-4f80-b51d-540d4ed88c3e
using Roots: find_zero, Brent

# ╔═╡ cdd24518-1cd3-43af-9a88-f0a8cd3cd6ed
md"""
`continuous-time-moll-solution.jl` | **Version 1.1** | *last updated: May 2, 2023* | *created by [Daniel Schmidt](https://github.com/danieljschmidt)*
"""

# ╔═╡ 0edf9214-7213-4b1d-8fa6-54a365525d29
md"""
# Huggett model in continuous time

In this notebook, we consider a Huggett economy in continuous time. Income follows a Poisson process.

More information on the algorithms can be found in the [Online Appendix of Achdou et al. (2021)](https://benjaminmoll.com/wp-content/uploads/2020/02/HACT_Numerical_Appendix.pdf). The Julia code in this notebook follows the closely the [Matlab code snippets](https://benjaminmoll.com/codes/) that Ben Moll uploaded on his website.

**Warning**

The code is not particularly robust to changes in the parameters. If you change one model parameter and get an error message, it sometimes helps to increase the maximum asset value on the grid.
"""

# ╔═╡ c3773842-4fa1-4f80-a8a0-82d4d9ca49bc
md"""
# Two income states
"""

# ╔═╡ 1c23af35-64f5-4b96-9eab-98ee9b1ecb4c
md"""
## Model
"""

# ╔═╡ 64d44910-988c-4e24-baf6-6408da65bd21
@with_kw struct HuggettPoisson2
	
	σ::Float64 = 2.   # risk aversion coefficient u'(c) = c^(-σ)
	ρ::Float64 = 0.05 # rate of time preference

	N_z = 2
	z::Matrix{Float64} = [0.1 0.2]   # income states (row vector)
	λ::Matrix{Float64} = [0.02 0.03] # intensities (row vector)

	# asset grid parameters
	N_a::Int64 = 500
	aₘᵢₙ::Float64 = - 0.1
	aₘₐₓ::Float64 = 1.5
	da::Float64 = (aₘₐₓ - aₘᵢₙ)/(N_a - 1)
	
end

# ╔═╡ ac27dd69-1216-4a02-ba62-ebb098b33fa1
md"""
We work with an equi-spaced asset grid with $N_a$ grid points. The difference between two grid points is denoted by $\Delta a$. (Section 7 in the online appendix explains how to deal with non-uniform grids.)
"""

# ╔═╡ 3dd0c186-04f0-425c-93dc-825c7d4b606e
function construct_a(m)
	(; N_a, aₘᵢₙ, aₘₐₓ) = m
	[aᵢ for aᵢ in range(aₘᵢₙ, aₘₐₓ, N_a)] |> hcat # asset grid (column vector)
end

# ╔═╡ 2289c7a7-3493-4bfb-8ffe-31b074d17b14
md"""
## HJB equation (implicit method)
"""

# ╔═╡ 0caee0bf-77c0-4542-a68e-9052d230ca74
md"""
$$\rho v_1(a) = \max_c u(c) + v_1'(a) (z_1 + ra - c) + \lambda_1(v_2(a) - v_1(a))$$
$$\rho v_2(a) = \max_c u(c) + v_2'(a) (z_2 + ra - c) + \lambda_2(v_1(a) - v_2(a))$$
"""

# ╔═╡ 38555a5e-5d39-4c61-9381-94c8fb67a257
md"""
**Algorithm**

(Notation: $v_{i,j}$ is short-hand notation for $v_j(a_i)$.)

Start with an initial guess for the value function $v_{i,j}^0$. A natural choice is
$$v_{i,j}^0 = \frac{u(z_j + ra_i)}{\rho}$$.

For n = 1, ... maxit 

(1) Approximate $(v_{i,j}^n)'$, $j=1,2$ using a finite difference method:

(Notation: Superscript $n$ is omitted.) 

- forward difference $v_{i,j,F}' = \frac{v_{i+1,j} - v_{i,j}}{\Delta a}$
- backward diffrence $v_{i,j,B}' = \frac{v_{i,j} - v_{i-1,j}}{\Delta a}$

The state constraint $a \ge a_\text{min}$ needs to be enforced by setting $v'_{1,j,B} = u'(z_j + ra_\text{min})$.

- savings according to forward difference $s_{i,j,F} = z_j + ra_i - (u')^{-1}(v'_{i,j,F})$
- savings according to backward difference $s_{i,j,B} = z_j + ra_i - (u')^{-1}(v'_{i,j,B})$

The finite difference approximation of $(v_{i,j}^n)'$ is

$$v'_{i,j} = v'_{i,j,F} 1_{s_{i,j,F}>0} + v'_{i,j,B} 1_{s_{i,j,B}<0} + \bar{v}_{i,j} 1_{s_{i,j,F} \le 0 \le s_{i,j,B}}$$

where $\bar{v}_{i,j} = u'(s_j + r a_i)$.

(We assume concavity of the value function here so that the case $s_{i,j,F}>0$ and $s_{i,j,B}<0$ cannot occur.)

(2) Compute the consumption policy implied by the value function $c_{i,j}^n = (u')^{-1}[(v_{i,j}^n)']$

(3) Find updated value function $v^{n+1}$:

```math
\begin{align}
&\frac{v_{i,j}^{n+1} - v_{i,j}^{n}}{\Delta} + \rho v_{i,j}^{n+1} = \\
&u(c_{i,j}^n) + (v_{i,j,F}^{n+1})'{\underbrace{[z_j + ra_i - c_{i,j,F}^n]}_{=s_{i,j,F}^n}}^+ + (v_{i,j,B}^{n+1})'{\underbrace{[z_j + ra_i - c_{i,j,B}^n]}_{=s_{i,j,B}^n}}^- + \lambda_j (v_{i,-j}^{n+1} - v_{i,j}^{n+1})
\end{align}
```

where $\Delta$ is the step size.

This is a system of $2N_a$ linear equations. Since $v^{n+1}$ is implicitly defined by the equations above, this approach is referred to as the implicit method.

The system of equations can be written in matrix notation as 

$$\frac{1}{\Delta} (v^{n+1} - v^n) + \rho v^{n+1} = u^n + A^n v^{n+1}$$

The $2N_a \times 2N_a$ matrix $A^n$ can be written as a sum of two matrices $\bar{A}^n$ and $A_\text{switch}$:

$A^n = \bar{A}^n + A_\text{switch} = \begin{pmatrix} \bar{A}_{11}^n & 0 \\ 0 & \bar{A}_{22}^n \end{pmatrix} + \begin{pmatrix} -\lambda_1 I & \lambda_1 I \\ \lambda_2 I & -\lambda_2 I \end{pmatrix}$

where $I$ is a $N_a \times N_a$ identity matrix. Since $A_\text{switch}$ stays unchanged, it can be pre-computed outside the for-loop.

The $N_a \times N_a$ submatrices $\bar{A}_{11}^n$ and $\bar{A}_{22}^n$ are tri-diagonal:
- The -1 diagonal is filled with $x_{i,j} = - \frac{(s^n_{i,j,B})^-}{\Delta a}$, $i=2, \dots N_a$
- The main diagonal is filled with $y_{i,j} = - \frac{(s^n_{i,j,F})^+}{\Delta a} + \frac{(s^n_{i,j,B})^-}{\Delta a}$, $i=1, \dots N_a$
- The +1 diagonal is filled with $z_{i,j} = \frac{(s^n_{i,j,F})^+}{\Delta a}$, $i=1, \dots N_a - 1$

Since $A^n$ is a sparse matrix, computers can solve the system of linear equations quickly even for large $N_a$.

(4) Stop if $v^{n+1}$ is close enough to $v^n$. 

"""

# ╔═╡ 4d7ee33f-ff78-4ea9-838b-a8320df4651f
function solve_HJB_implicit(m::HuggettPoisson2, r; maxit = 100, crit = 1e-6, Δ = 1000)

	(; σ, ρ, z, λ, N_a, aₘᵢₙ, aₘₐₓ, da) = m

	# construct asset grid
	a = construct_a(m)

	# initialize arrays for forward and backward difference
	dvf = zeros(N_a, 2)
	dvb = zeros(N_a, 2)

	# precompute A_switch matrix
	id = sparse(I, N_a, N_a)
	A_switch_1 = hcat(-λ[1] * id,  λ[1] * id)
	A_switch_2 = hcat( λ[2] * id, -λ[2] * id)
	A_switch   = vcat(A_switch_1, A_switch_2)

	# initial guess for value function
	v₀ = zeros(N_a, 2)
	for (i, zᵢ) in enumerate(z)
		v₀[:,i] = (zᵢ .+ r * a).^(1-σ) / (1-σ) / ρ
	end
	v = v₀

	# initialize vector that keeps track of convergence
	dist = - ones(maxit)

	for it in range(1, maxit)

		# STEP 1

		# forward difference
		dvf[1:N_a-1,:] = (v[2:N_a,:] - v[1:N_a-1,:]) / da
		dvf[N_a,:] = (z .+ r * aₘₐₓ) .^ (-σ) # boundary condition a  <= a_max

		# backward difference
		dvb[2:N_a,:] = (v[2:N_a,:] - v[1:N_a-1,:]) / da
		dvb[1,:] = (z .+ r * aₘᵢₙ) .^ (-σ) # boundary condition a >= a_min
	
		I_concave = dvb .> dvf # problems if value function not concave

		# consumption and savings with forward difference
		cf = dvf .^ (-1/σ)
		ȧf = z .+ r .* a - cf

		# consumption and savings with backward difference
		cb = dvb .^ (-1/σ)
		ȧb = z .+ r .* a - cb

		# consumption and derivate of value function at steady state
		c0 = z .+ r .* a
		dv0 = c0 .^ (-σ)

		If = ȧf .> 0 # positive drift => forward difference
		Ib = ȧb .< 0 # negative drift => backward difference
		Ib[N_a,:] .= 1. # make sure backward difference is used at last grid point
		If[N_a,:] .= 0.
		I0 = (1 .- If .- Ib) # steady state
	
		dv_upwind = dvf.*If + dvb.*Ib + dv0.*I0

		# STEP 2
	
		c = dv_upwind .^ (-1/σ)
		u = c.^(1-σ)/(1-σ)

		# STEP 3

		X = - min.(ȧb,0)/da
		Y = - max.(ȧf,0)/da + min.(ȧb,0)/da
		Z =   max.(ȧf,0)/da

		A11 = spdiagm(-1 => X[2:N_a,1], 0 => Y[:,1], 1 => Z[1:N_a-1,1])
		A22 = spdiagm(-1 => X[2:N_a,2], 0 => Y[:,2], 1 => Z[1:N_a-1,2])
		A1 = hcat(A11, spzeros(N_a, N_a))
		A2 = hcat(spzeros(N_a, N_a), A22)
		A = vcat(A1, A2) + A_switch

		B = (ρ + 1/Δ) * sparse(I, 2*N_a, 2*N_a) - A
		b = vec(u) + vec(v)/Δ
		v_new_stacked = B \ b
		v_new = reshape(v_new_stacked, N_a, 2)

		# STEP 4

		v_change = v_new - v
		dist[it] = maximum(abs.(v_change))
		
		v = v_new

		if dist[it] < crit

			ȧ = z .+ r.*a - c

			return v, c, ȧ, A, it, dist

		end

	end

	error("Algorithm did not converge")

end

# ╔═╡ 1fbf9f02-7ad2-4ddd-ac2c-92af79c9ed02
md"""
## KF equation
"""

# ╔═╡ 2e09462e-6030-4e33-bc7a-9d2faed4ca74
md"""
$$0 = - \frac{d}{da}[s_1(a)g_1(a)] - \lambda_1 g_1(a) + \lambda_2 g_2(a)$$
$$0 = - \frac{d}{da}[s_2(a)g_2(a)] - \lambda_2 g_2(a) + \lambda_1 g_1(a)$$

where $s_j(a) + z_j + ra - c_j(a)$

$$1 = \int_{\bar{a}}^\infty g_1(a)da + \int_{\bar{a}}^\infty g_2(a)da$$

**Algorithm**

A finite difference approximation of the KF equation results into the matrix equation $A^T g = 0$ where $A$ is the matrix from implicit algorithm for the HJB equation.
"""

# ╔═╡ e5cfdbc2-f592-40bb-ba5d-07f455dd5bd4
md"""
## Putting everything together
"""

# ╔═╡ 23a991be-7c8b-45e2-bd75-af5e146fc6b0
m = HuggettPoisson2();

# ╔═╡ deeff3d5-3856-43cb-8469-2a4d6d7fca4f
md"""
## Equilibrium interest rate
"""

# ╔═╡ b6101102-2054-4932-b6b6-5070cd84f2be
md"""
$$0 = \int_{\bar{a}}^\infty ag_1(a)da + \int_{\bar{a}}^\infty ag_2(a)da = S(r)$$
"""

# ╔═╡ a8f1dc13-b73c-44b0-8e63-82431f904313
initial_bracket = (0.01, 0.03)

# ╔═╡ b26682fb-4b4b-45bc-b406-7a15637f8199
md"""
# Three income states 
"""

# ╔═╡ 505d44ec-1c16-4cc3-851d-a9d7feb18cb3
md"""
## Model
"""

# ╔═╡ 288c66fc-aa44-42d8-b19b-c9725bef2d44
md"""
In the case of 2 income states, we represented the intensities of the Poisson process as a vector $\lambda = [\lambda_1, \lambda_2]$ where $\lambda_j$ is the rate at which agents leave income state $j$ and switch to the other income state. An alternative representation would be a matrix 

$\Lambda = \begin{pmatrix}
-\lambda_1 & \lambda_1 \\
\lambda_2 & -\lambda_2
\end{pmatrix}$

In the case of 3 income states, the matrix representation becomes more convenient:

$$\Lambda = \begin{pmatrix} 
-\lambda_{12}-\lambda_{13} & \lambda_{12} & \lambda_{13} \\ 
\lambda_{21} & -\lambda_{21} - \lambda_{23} & \lambda_{23} \\
\lambda_{31} & \lambda_{32} & -\lambda_{31} & -\lambda_{32}
\end{pmatrix}$$

where $\lambda_{jk}$ is the rate at which agents in state $j$ switch to state $k$.
"""

# ╔═╡ d7f08043-fa3e-476c-a25a-dac7c16cc570
@with_kw struct HuggettPoisson3
	
	σ::Float64 = 2.   # risk aversion coefficient u'(c) = c^(-σ)
	ρ::Float64 = 0.05 # rate of time preference

	N_z = 3
	z::Matrix{Float64} = [0.1 0.15 0.2] # income states (row vector)
	Λ::Matrix{Float64} = [-0.06 0.04 0.02; 0.02 -0.04 0.02; 0.02 0.04 -0.06]

	@assert all(abs.(sum(Λ; dims=2)) .< 1e-12)
	
	# asset grid parameters
	N_a::Int64 = 500
	aₘᵢₙ::Float64 = - 0.1
	aₘₐₓ::Float64 = 1.
	da::Float64 = (aₘₐₓ - aₘᵢₙ)/(N_a - 1)
	
end

# ╔═╡ 49d69255-20f3-490d-b068-81ec0cb22ff3
md"""
## Exercise 1: HJB equation
"""

# ╔═╡ ec990221-bff1-41f3-8a94-2ef23a836f2c
md"""
👉 Write down the system of HJB equations for the case of 3 income states.
"""

# ╔═╡ 90d0941c-d952-44c5-8acf-6adf30361b57
md"""
Version 1:

$$\rho v_j(a) = \max_c u(c) + v_j'(a) (z_j + ra - c) + \sum_{k=1}^3 \Lambda_{j,k} v_k(a)$$

Version 2:

$$\rho v_j(a) = \max_c u(c) + v_j'(a) (z_j + ra - c) + \sum_{k\neq j} \lambda_{j,k} (v_k(a) - v_j(a))$$

for $j = 1,2,3$
"""

# ╔═╡ fe3bf03d-eb60-40d6-aae8-8e85b0bb9213
md"""
👉 How does the matrix $A^n$ look like for 3 income states?
"""

# ╔═╡ 514c081b-5343-4e63-abdf-eda3356c110a
md"""
```math
\begin{align}
A^n = \begin{pmatrix} 
	\bar{A}_{11}^n & 0 & 0 \\ 
	0 & \bar{A}_{22}^n & 0 \\ 
	0 & 0 & \bar{A}_{33}^n 
\end{pmatrix} + \begin{pmatrix} 
	-(\lambda_{12} + \lambda_{13}) I & \lambda_{12} I & \lambda_{13} I \\ 
	\lambda_{21} I & -(\lambda_{21} + \lambda_{23}) I & \lambda_{23} I \\
	\lambda_{31} I & \lambda_{32} I & -(\lambda_{31} + \lambda_{32})I
\end{pmatrix}
\end{align}
```
"""

# ╔═╡ 612478ce-215b-4020-a2f7-a64818f8fb03
md"""
👉 Adapt the algorithm for solving the HJB equation so that it can deal with 3 income states.

(Writing separate algorithms for 2 and 3 income states is of course not very elegant from a programming perspective, but it hopefully helps you to understand the algorithm in Achdou et al. better.) 
"""

# ╔═╡ ec54c169-f795-40fe-8c5c-b63600834d77
function solve_HJB_implicit(m::HuggettPoisson3, r; maxit = 100, crit = 1e-6, Δ = 1000)

	(; σ, ρ, z, Λ, N_a, aₘᵢₙ, aₘₐₓ, da) = m

	# construct asset grid
	a = construct_a(m)

	# initialize arrays for forward and backward difference
	dvf = zeros(N_a, 3)
	dvb = zeros(N_a, 3)

	# precompute A_switch matrix
	id = sparse(I, N_a, N_a)
	A_switch_1 = hcat(Λ[1,1] * id,  Λ[1,2] * id, Λ[1,3] * id)
	A_switch_2 = hcat(Λ[2,1] * id,  Λ[2,2] * id, Λ[2,3] * id)
	A_switch_3 = hcat(Λ[3,1] * id,  Λ[3,2] * id, Λ[3,3] * id)
	A_switch   = vcat(A_switch_1, A_switch_2, A_switch_3)

	# initial guess for value function
	v₀ = zeros(N_a, 3)
	for (i, zᵢ) in enumerate(z)
		v₀[:,i] = (zᵢ .+ r * a).^(1-σ) / (1-σ) / ρ
	end
	v = v₀

	# initialize vector that keeps track of convergence
	dist = - ones(maxit)

	for it in range(1, maxit)

		# STEP 1

		# forward difference
		dvf[1:N_a-1,:] = (v[2:N_a,:] - v[1:N_a-1,:]) / da
		dvf[N_a,:] = (z .+ r * aₘₐₓ) .^ (-σ) # boundary condition a  <= a_max

		# backward difference
		dvb[2:N_a,:] = (v[2:N_a,:] - v[1:N_a-1,:]) / da
		dvb[1,:] = (z .+ r * aₘᵢₙ) .^ (-σ) # boundary condition a >= a_min
	
		I_concave = dvb .> dvf # problems if value function not concave

		# consumption and savings with forward difference
		cf = dvf .^ (-1/σ)
		ȧf = z .+ r .* a - cf

		# consumption and savings with backward difference
		cb = dvb .^ (-1/σ)
		ȧb = z .+ r .* a - cb

		# consumption and derivate of value function at steady state
		c0 = z .+ r .* a
		dv0 = c0 .^ (-σ)

		If = ȧf .> 0 # positive drift => forward difference
		Ib = ȧb .< 0 # negative drift => backward difference
		Ib[N_a,:] .= 1. # make sure backward difference is used at last grid point
		If[N_a,:] .= 0.
		I0 = (1 .- If .- Ib) # steady state
	
		dv_upwind = dvf.*If + dvb.*Ib + dv0.*I0

		# STEP 2
	
		c = dv_upwind .^ (-1/σ)
		u = c.^(1-σ)/(1-σ)

		# STEP 3

		X = - min.(ȧb,0)/da
		Y = - max.(ȧf,0)/da + min.(ȧb,0)/da
		Z =   max.(ȧf,0)/da

		zero = spzeros(N_a, N_a)
		A11 = spdiagm(-1 => X[2:N_a,1], 0 => Y[:,1], 1 => Z[1:N_a-1,1])
		A22 = spdiagm(-1 => X[2:N_a,2], 0 => Y[:,2], 1 => Z[1:N_a-1,2])
		A33 = spdiagm(-1 => X[2:N_a,3], 0 => Y[:,3], 1 => Z[1:N_a-1,3])
		A1 = hcat(A11, zero, zero)
		A2 = hcat(zero, A22, zero)
		A3 = hcat(zero, zero, A33)
		A = vcat(A1, A2, A3) + A_switch

		B = (ρ + 1/Δ) * sparse(I, 3*N_a, 3*N_a) - A
		b = vec(u) + vec(v)/Δ
		v_new_stacked = B \ b
		v_new = reshape(v_new_stacked, N_a, 3)

		# STEP 4

		v_change = v_new - v
		dist[it] = maximum(abs.(v_change))
		
		v = v_new

		if dist[it] < crit

			ȧ = z .+ r.*a - c

			return v, c, ȧ, A, it, dist

		end

	end

	error("Algorithm did not converge")

end

# ╔═╡ 9ebdb7e1-c1e3-4e22-8c24-e82e5d927160
md"""
## Results
"""

# ╔═╡ 492aa578-b079-4710-b1e9-2c887922d9f2
m3 = HuggettPoisson3();

# ╔═╡ d4efae22-e989-4d59-b916-ecc6d3c8b0e3
initial_bracket3 = (0.01, 0.03)

# ╔═╡ f8c3b95f-0895-4301-9eaf-02b238a46ec9
md"""
# $N_z$ income states
"""

# ╔═╡ d7cbcf7e-a467-4c51-bc9e-9b04aa943e3f
md"""
## Model
"""

# ╔═╡ f783c67b-5456-43cb-baa7-7812bf797723
@with_kw struct HuggettPoissonN
	
	σ::Float64 = 2.   # risk aversion coefficient u'(c) = c^(-σ)
	ρ::Float64 = 0.05 # rate of time preference

	N_z::Int64 = 4
	z::Matrix{Float64} = [0.1 0.13 0.17 0.2] # income states (row vector)
	Λ::Matrix{Float64} = [
		-0.07 0.04 0.02 0.01; 
		0.02 -0.05 0.02 0.01; 
		0.01 0.02 -0.05 0.02;
		0.01 0.02 0.04 -0.07
	]

	@assert all(abs.(sum(Λ; dims=2)) .< 1e-12)
	
	# asset grid parameters
	N_a::Int64 = 500
	aₘᵢₙ::Float64 = - 0.1
	aₘₐₓ::Float64 = 1.5
	da::Float64 = (aₘₐₓ - aₘᵢₙ)/(N_a - 1)
	
end

# ╔═╡ f8686182-95b7-497d-9b3a-8d272efd9f90
md"""
## Exercise 2: HJB equation (optional)
"""

# ╔═╡ 86dced4d-2eb3-4f67-835f-3b9b4f247007
md"""
👉 Adapt the algorithm for solving the HJB equation so that it can deal with an arbitrary number $N_z$ of income states.
"""

# ╔═╡ 573757f8-8093-4310-8073-11ae7fcff776
function solve_HJB_implicit(m::HuggettPoissonN, r; maxit = 100, crit = 1e-6, Δ = 1000)

	(; σ, ρ, N_z, z, Λ, N_a, aₘᵢₙ, aₘₐₓ, da) = m

	# construct asset grid
	a = construct_a(m)

	# initialize arrays for forward and backward difference
	dvf = zeros(N_a, N_z)
	dvb = zeros(N_a, N_z)

	# precompute A_switch matrix
	id = sparse(I, N_a, N_a)
	A_switch_rows = [
		hcat([Λ[j,k] * id for k in range(1,N_z)]...) for j in range(1,N_z)
	]
	A_switch   = vcat(A_switch_rows...)

	# initial guess for value function
	v₀ = zeros(N_a, N_z)
	for (i, zᵢ) in enumerate(z)
		v₀[:,i] = (zᵢ .+ r * a).^(1-σ) / (1-σ) / ρ
	end
	v = v₀

	# initialize vector that keeps track of convergence
	dist = - ones(maxit)

	for it in range(1, maxit)

		# STEP 1

		# forward difference
		dvf[1:N_a-1,:] = (v[2:N_a,:] - v[1:N_a-1,:]) / da
		dvf[N_a,:] = (z .+ r * aₘₐₓ) .^ (-σ) # boundary condition a  <= a_max

		# backward difference
		dvb[2:N_a,:] = (v[2:N_a,:] - v[1:N_a-1,:]) / da
		dvb[1,:] = (z .+ r * aₘᵢₙ) .^ (-σ) # boundary condition a >= a_min
	
		I_concave = dvb .> dvf # problems if value function not concave

		# consumption and savings with forward difference
		cf = dvf .^ (-1/σ)
		ȧf = z .+ r .* a - cf

		# consumption and savings with backward difference
		cb = dvb .^ (-1/σ)
		ȧb = z .+ r .* a - cb

		# consumption and derivate of value function at steady state
		c0 = z .+ r .* a
		dv0 = c0 .^ (-σ)

		If = ȧf .> 0 # positive drift => forward difference
		Ib = ȧb .< 0 # negative drift => backward difference
		Ib[N_a,:] .= 1. # make sure backward difference is used at last grid point
		If[N_a,:] .= 0.
		I0 = (1 .- If .- Ib) # steady state
	
		dv_upwind = dvf.*If + dvb.*Ib + dv0.*I0

		# STEP 2
	
		c = dv_upwind .^ (-1/σ)
		u = c.^(1-σ)/(1-σ)

		# STEP 3

		X = - min.(ȧb,0)/da
		Y = - max.(ȧf,0)/da + min.(ȧb,0)/da
		Z =   max.(ȧf,0)/da

		A_bar = blockdiag([
			spdiagm(-1 => X[2:N_a,j], 0 => Y[:,j], 1 => Z[1:N_a-1,j])
		for j in range(1,N_z)]...)
		
		A = A_bar + A_switch

		B = (ρ + 1/Δ) * sparse(I, N_z*N_a, N_z*N_a) - A
		b = vec(u) + vec(v)/Δ
		v_new_stacked = B \ b
		v_new = reshape(v_new_stacked, N_a, N_z)

		# STEP 4

		v_change = v_new - v
		dist[it] = maximum(abs.(v_change))
		
		v = v_new

		if dist[it] < crit

			ȧ = z .+ r.*a - c

			return v, c, ȧ, A, it, dist

		end

	end

	error("Algorithm did not converge")

end

# ╔═╡ 98a7d8e0-1741-4447-b612-e40491fa8673
t_impl = @elapsed solve_HJB_implicit(m, 0.03)

# ╔═╡ bc435feb-ed9f-4662-b023-5eae0f1e778a
md"""
## Results
"""

# ╔═╡ 9349d7cf-ddab-41a8-9ba2-44ea849619b3
mN = HuggettPoissonN();

# ╔═╡ 110ed843-0259-43bc-9e60-189dcd4515b3
initial_bracketN = (0.01, 0.035)

# ╔═╡ e4035abe-11a1-4c2c-8312-4d1c71e2f9ab
md"""
# Appendix 
"""

# ╔═╡ ab69ab43-99bf-4a92-9698-70e170761e82
md"""
## HJB equation (explicit method)
"""

# ╔═╡ 5c7c3dc0-7848-4431-829e-508664d9c5af
md"""
**Basic dea**

Start with some initial guess $v_{i,j}^0$ and update $v_{i,j}^n$ as follows:

$$\frac{v_{i,j}^{n+1} - v_{i,j}^n}{\Delta} + \rho v_{i,j}^n = u(c_{i,j}^n) + (v_{i,j}^n)'(z_j + ra_i - c_{i,j}^n) + \lambda_i (v_{i,-j}^n - v_{i,j}^n)$$

In contrast to the implicit method, we can rearrange for $v_{i,j}^{n+1}$ in the equation above.

The disadvantage of the explicit method is that it converges only if $\Delta$ is not too large.
"""

# ╔═╡ b099dbbf-9648-44c5-984c-fdd80ee81469
function solve_HJB_explicit(m::HuggettPoisson2, r; maxit = 100000, crit = 1e-6)

	(; σ, ρ, z, λ, N_a, aₘᵢₙ, aₘₐₓ, da) = m

	# construct asset grid
	a = construct_a(m)

	# initialize arrays for forward and backward difference
	dvf = zeros(N_a, 2)
	dvb = zeros(N_a, 2)

	# initial guess for value function
	v₀ = zeros(N_a, 2)
	for (i, zᵢ) in enumerate(z)
		v₀[:,i] = (zᵢ .+ r * a).^(1-σ) / (1-σ) / ρ
	end
	v = v₀

	# initialize vector that keeps track of convergence
	dist = - ones(maxit)

	# step size for updating the value function
	Δ = .9 * da / (z[2] .+ r.*aₘₐₓ)

	for it in range(1, maxit)

		# forward difference
		dvf[1:N_a-1,:] = (v[2:N_a,:] - v[1:N_a-1,:]) / da
		dvf[N_a,:] = (z .+ r * aₘₐₓ) .^ (-σ) # boundary condition a  <= a_max

		# backward difference
		dvb[2:N_a,:] = (v[2:N_a,:] - v[1:N_a-1,:]) / da
		dvb[1,:] = (z .+ r * aₘᵢₙ) .^ (-σ) # boundary condition a >= a_min
	
		I_concave = dvb .> dvf # problems if value function not concave

		# consumption and savings with forward difference
		cf = dvf .^ (-1/σ)
		ȧf = z .+ r .* a - cf

		# consumption and savings with backward difference
		cb = dvb .^ (-1/σ)
		ȧb = z .+ r .* a - cb

		# consumption and derivate of value function at steady state
		c0 = z .+ r .* a
		dv0 = c0 .^ (-σ)

		If = ȧf .> 0 # positive drift => forward difference
		Ib = ȧb .< 0 # negative drift => backward difference
		Ib[N_a,:] .= 1. # make sure backward difference is used at last grid point
		If[N_a,:] .= 0.
		I0 = (1 .- If .- Ib) # steady state
	
		dv_upwind = dvf.*If + dvb.*Ib + dv0.*I0
	
		c = dv_upwind .^ (-1/σ)
		ȧ = z .+ r.*a - c
		
		v_switch = zeros(N_a, 2)
		v_switch[:,2] = v[:,1]
		v_switch[:,1] = v[:,2]

		# HJB equation
		v_change = c.^(1-σ)/(1-σ) + dv_upwind .* ȧ + ones(N_a,1)*λ.*(v_switch - v) - ρ*v

		# updating the value function
		v[:,:] = v + Δ * v_change

		dist[it] = maximum(abs.(v_change))

		if dist[it] < crit
			
			return v, c, ȧ, it, dist

		end

	end

	error("Algorithm did not converge")

end

# ╔═╡ 4bfa5d92-b177-4442-b045-e05cc48b6cc4
t_expl = @elapsed solve_HJB_explicit(m, 0.03; crit=1e-6)

# ╔═╡ fd0fb774-a805-4739-b570-0d2e191a3294
md"""
## Implicit vs. explicit method
"""

# ╔═╡ eb7bbd16-04d3-4d7d-b4af-e77f89e4180e
md"""
**Implicit method**
"""

# ╔═╡ bd2e4d28-c68b-45c9-b68e-b477b44fcd75
md"""
**Explicit method**
"""

# ╔═╡ 6e607792-e297-483f-8917-c871fa0c26d0
md"""
## Helper functions
"""

# ╔═╡ 0605f7f4-7123-4c1e-a0f6-aefdfeaed25d
HuggettPoisson = Union{HuggettPoisson2, HuggettPoisson3, HuggettPoissonN};

# ╔═╡ eb565042-1823-4d5a-b4d1-ee314dccd4e0
function solve_KF(m::HuggettPoisson, A)

	(; N_a, da, N_z) = m
	
	AT = transpose(A)
	b = zeros(N_z*N_a, 1)
	
	i_fix = 1
	b[i_fix] = .1
	AT[i_fix,:] = hcat(zeros(1, i_fix-1), 1., zeros(1,N_z*N_a-i_fix))

	g_stacked = AT\b
	g_sum = sum(g_stacked) * da
	g_stacked_norm = g_stacked ./ g_sum

	@assert sum(g_stacked_norm) * da ≈ 1
	
	g = reshape(g_stacked_norm, N_a, N_z)

end

# ╔═╡ 532d0b24-6ace-4579-bf2a-d12c07ee9436
function results_to_df(m::HuggettPoisson; v, c, ȧ, g=nothing)
	
	(; N_a, N_z, z) = m

	a = construct_a(m)

	df = DataFrame()
	df.a = a * ones(1, N_z) |> vec
	df.z = ones(N_a, 1) * z |> vec
	df.c = c |> vec
	df.ȧ = ȧ |> vec
	df.v = v |> vec
	
	if ! isnothing(g)
		df.g = g |> vec
	end

	df
	
end

# ╔═╡ e1376e99-a636-4d28-b711-2dd4be66374f
function solve_df(m::HuggettPoisson, r; maxit = 100, crit = 1e-6, Δ = 1000)
	
	v, c, ȧ, A, it_last, dist = solve_HJB_implicit(m, r; maxit, crit, Δ)
	g = solve_KF(m, A)
	df = results_to_df(m; v, c, ȧ, g)
	
	return df, it_last, dist
	
end

# ╔═╡ 4de350bb-d2be-46b1-8558-a49f54a29dd1
(df, it_last, dist) = solve_df(m, 0.03; maxit = 100);

# ╔═╡ 1503b0d4-6d0e-4b5d-896f-e13c093ad3d4
let 
	
	df.g_max = min.(df.g,df.g[2])
	# do not show the point mass at the borrowing constraint
	
	@chain df begin
		stack(Not([:a, :z, :g]))
		data(_) * mapping(:a, :value, layout = :variable, color = :z => nonnumeric) * visual(Lines)
		draw(; facet = (linkyaxes = false, ), legend = (position = :top, titleposition = :left))
	end

end

# ╔═╡ ae8fd43c-f658-47b1-8781-6f699ade6bdb
let 
	df_dist = DataFrame(
		iteration = range(1, it_last), 
		time = range(0, t_impl, it_last),
		log10_dist = log10.(dist[1:it_last])
		)
	figure = (; resolution = (500, 250))
	@chain df_dist begin
		data(_) * mapping(:time, :log10_dist) * visual(Lines)
		draw(; figure)
	end
end

# ╔═╡ 19e28c66-a389-4903-82a5-c963cf0b90b9
function excess_demand(m::HuggettPoisson, r; maxit = 100, crit = 1e-6, Δ = 1000)
	(; da) = m
	(df, it_last, dist) = solve_df(m, r; maxit, crit, Δ)
	A = dot(df.a, df.g) * da

end

# ╔═╡ bd353706-be2d-480d-8ebb-cf20cab0dbec
r_eq = find_zero(r -> excess_demand(m, r), initial_bracket, Brent())

# ╔═╡ d31538cc-4223-47bf-ad19-b1ed9c1ab1f5
r_eq3 = find_zero(r -> excess_demand(m3, r), initial_bracket3, Brent())

# ╔═╡ 2d15caf9-986d-4595-ab24-39ada24c9778
r_eqN = find_zero(r -> excess_demand(mN, r), initial_bracketN, Brent())

# ╔═╡ f29e5256-ccec-4c99-9f90-5f98142b1f40
(df3, it_last3, dist3) = solve_df(m3, r_eq3);

# ╔═╡ 30496b92-df7c-4f48-9983-5cbb99d81f7a
let 
	
	df3.g_max = min.(df3.g, df3.g[2])
	# do not show the point mass at the borrowing constraint
	
	@chain df3 begin
		stack(Not([:a, :z, :g]))
		data(_) * mapping(:a, :value, layout = :variable, color = :z => nonnumeric) * visual(Lines)
		draw(; facet = (linkyaxes = false, ), legend = (position = :top, titleposition = :left))
	end

end

# ╔═╡ 9f901ed5-0458-4358-a793-a530e397c01f
(dfN, it_lastN, distN) = solve_df(mN, r_eqN);

# ╔═╡ 6f18ea5e-5816-4791-974f-78910f393e57
let 
	
	dfN.g_max = min.(dfN.g, dfN.g[1]/5)
	# do not show the point mass at the borrowing constraint
	
	@chain dfN begin
		stack(Not([:a, :z, :g]))
		data(_) * mapping(:a, :value, layout = :variable, color = :z => nonnumeric) * visual(Lines)
		draw(; facet = (linkyaxes = false, ), legend = (position = :top, titleposition = :left))
	end

end

# ╔═╡ f8fbff0d-15d4-43ca-9f9c-29788ff793ec
function solve_explicit_df(m::HuggettPoisson2, r; maxit = 100000, crit = 1e-6)
	
	v, c, ȧ, it_last, dist = solve_HJB_explicit(m, r; maxit, crit)
	df = results_to_df(m; v, c, ȧ)
	
	return df, it_last, dist
	
end

# ╔═╡ 4894a323-c8c8-4f34-b311-20c64176b89d
(df_expl, it_last_expl, dist_expl) = solve_explicit_df(m, 0.03; crit=1e-6);

# ╔═╡ ebd88b43-e277-4c79-b443-1661a3c438b8
(df_expl[:,[:c, :ȧ, :v]] .- df[:,[:c, :ȧ, :v]])

# ╔═╡ 264fc65e-d09a-4c67-94de-f845d42d18a3
let 
	df_dist = DataFrame(
		iteration = range(1, it_last_expl), 
		time = range(0, t_expl, it_last_expl),
		log10_dist = log10.(dist_expl[1:it_last_expl])
		)
	figure = (; resolution = (500, 250))
	@chain df_dist begin
		data(_) * mapping(:time, :log10_dist) * visual(Lines)
		draw(; figure)
	end
end

# ╔═╡ 518eec58-eb4b-4294-9090-b6645f51a337
md"""
## Imported packages
"""

# ╔═╡ 5c1387ed-973c-4109-9ace-c473a4efe9ee
TableOfContents()

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
AlgebraOfGraphics = "cbdf2221-f076-402e-a563-3d30da359d67"
CairoMakie = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"
Chain = "8be319e6-bccf-4806-a6f7-6fae938471bc"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
Parameters = "d96e819e-fc66-5662-9728-84c9c7592b0a"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Roots = "f2b01f46-fcfa-551c-844a-d8ac1e96c665"
SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[compat]
AlgebraOfGraphics = "~0.6.14"
CairoMakie = "~0.10.4"
Chain = "~0.5.0"
DataFrames = "~1.5.0"
Parameters = "~0.12.3"
PlutoUI = "~0.7.50"
Roots = "~2.0.13"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.9.0"
manifest_format = "2.0"
project_hash = "6fdb7cb925bf14054da5b191e195a02a90f68a90"

[[deps.AbstractFFTs]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "16b6dbc4cf7caee4e1e75c49485ec67b667098a0"
uuid = "621f4979-c628-5d54-868e-fcf4e3e8185c"
version = "1.3.1"
weakdeps = ["ChainRulesCore"]

    [deps.AbstractFFTs.extensions]
    AbstractFFTsChainRulesCoreExt = "ChainRulesCore"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "8eaf9f1b4921132a4cff3f36a1d9ba923b14a481"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.1.4"

[[deps.AbstractTrees]]
git-tree-sha1 = "faa260e4cb5aba097a73fab382dd4b5819d8ec8c"
uuid = "1520ce14-60c1-5f80-bbc7-55ef81b5835c"
version = "0.4.4"

[[deps.Adapt]]
deps = ["LinearAlgebra", "Requires"]
git-tree-sha1 = "cc37d689f599e8df4f464b2fa3870ff7db7492ef"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "3.6.1"
weakdeps = ["StaticArrays"]

    [deps.Adapt.extensions]
    AdaptStaticArraysExt = "StaticArrays"

[[deps.AlgebraOfGraphics]]
deps = ["Colors", "Dates", "Dictionaries", "FileIO", "GLM", "GeoInterface", "GeometryBasics", "GridLayoutBase", "KernelDensity", "Loess", "Makie", "PlotUtils", "PooledArrays", "RelocatableFolders", "SnoopPrecompile", "StatsBase", "StructArrays", "Tables"]
git-tree-sha1 = "43c2ef89ca0cdaf77373401a989abae4410c7b8a"
uuid = "cbdf2221-f076-402e-a563-3d30da359d67"
version = "0.6.14"

[[deps.Animations]]
deps = ["Colors"]
git-tree-sha1 = "e81c509d2c8e49592413bfb0bb3b08150056c79d"
uuid = "27a7e980-b3e6-11e9-2bcd-0b925532e340"
version = "0.4.1"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Automa]]
deps = ["Printf", "ScanByte", "TranscodingStreams"]
git-tree-sha1 = "d50976f217489ce799e366d9561d56a98a30d7fe"
uuid = "67c07d97-cdcb-5c2c-af73-a7f9c32a568b"
version = "0.8.2"

[[deps.AxisAlgorithms]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "WoodburyMatrices"]
git-tree-sha1 = "66771c8d21c8ff5e3a93379480a2307ac36863f7"
uuid = "13072b0f-2c55-5437-9ae7-d433b7a33950"
version = "1.0.1"

[[deps.AxisArrays]]
deps = ["Dates", "IntervalSets", "IterTools", "RangeArrays"]
git-tree-sha1 = "1dd4d9f5beebac0c03446918741b1a03dc5e5788"
uuid = "39de3d68-74b9-583c-8d2d-e117c070f3a9"
version = "0.4.6"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "19a35467a82e236ff51bc17a3a44b69ef35185a2"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.8+0"

[[deps.CEnum]]
git-tree-sha1 = "eb4cb44a499229b3b8426dcfb5dd85333951ff90"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.4.2"

[[deps.CRC32c]]
uuid = "8bf52ea8-c179-5cab-976a-9e18b702a9bc"

[[deps.Cairo]]
deps = ["Cairo_jll", "Colors", "Glib_jll", "Graphics", "Libdl", "Pango_jll"]
git-tree-sha1 = "d0b3f8b4ad16cb0a2988c6788646a5e6a17b6b1b"
uuid = "159f3aea-2a34-519c-b102-8c37f9878175"
version = "1.0.5"

[[deps.CairoMakie]]
deps = ["Base64", "Cairo", "Colors", "FFTW", "FileIO", "FreeType", "GeometryBasics", "LinearAlgebra", "Makie", "SHA", "SnoopPrecompile"]
git-tree-sha1 = "2aba202861fd2b7603beb80496b6566491229855"
uuid = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"
version = "0.10.4"

[[deps.Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "CompilerSupportLibraries_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "4b859a208b2397a7a623a03449e4636bdb17bcf2"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.16.1+1"

[[deps.Calculus]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f641eb0a4f00c343bbc32346e1217b86f3ce9dad"
uuid = "49dc2e85-a5d0-5ad3-a950-438e2897f1b9"
version = "0.5.1"

[[deps.Chain]]
git-tree-sha1 = "8c4920235f6c561e401dfe569beb8b924adad003"
uuid = "8be319e6-bccf-4806-a6f7-6fae938471bc"
version = "0.5.0"

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "c6d890a52d2c4d55d326439580c3b8d0875a77d9"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.15.7"

[[deps.ColorBrewer]]
deps = ["Colors", "JSON", "Test"]
git-tree-sha1 = "61c5334f33d91e570e1d0c3eb5465835242582c4"
uuid = "a2cac450-b92f-5266-8821-25eda20663c8"
version = "0.4.0"

[[deps.ColorSchemes]]
deps = ["ColorTypes", "ColorVectorSpace", "Colors", "FixedPointNumbers", "PrecompileTools", "Random"]
git-tree-sha1 = "be6ab11021cd29f0344d5c4357b163af05a48cba"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.21.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "eb7f0f8307f71fac7c606984ea5fb2817275d6e4"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.4"

[[deps.ColorVectorSpace]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "SpecialFunctions", "Statistics", "TensorCore"]
git-tree-sha1 = "600cc5508d66b78aae350f7accdb58763ac18589"
uuid = "c3611d14-8923-5661-9e6a-0046d554d3a4"
version = "0.9.10"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "fc08e5930ee9a4e03f84bfb5211cb54e7769758a"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.10"

[[deps.CommonSolve]]
git-tree-sha1 = "9441451ee712d1aec22edad62db1a9af3dc8d852"
uuid = "38540f10-b2f7-11e9-35d8-d573e4eb0ff2"
version = "0.2.3"

[[deps.Compat]]
deps = ["UUIDs"]
git-tree-sha1 = "7a60c856b9fa189eb34f5f8a6f6b5529b7942957"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.6.1"
weakdeps = ["Dates", "LinearAlgebra"]

    [deps.Compat.extensions]
    CompatLinearAlgebraExt = "LinearAlgebra"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.0.2+0"

[[deps.ConstructionBase]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "89a9db8d28102b094992472d333674bd1a83ce2a"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.5.1"
weakdeps = ["IntervalSets", "StaticArrays"]

    [deps.ConstructionBase.extensions]
    IntervalSetsExt = "IntervalSets"
    StaticArraysExt = "StaticArrays"

[[deps.Contour]]
git-tree-sha1 = "d05d9e7b7aedff4e5b51a029dced05cfb6125781"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.6.2"

[[deps.Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[deps.DataAPI]]
git-tree-sha1 = "e8119c1a33d267e16108be441a287a6981ba1630"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.14.0"

[[deps.DataFrames]]
deps = ["Compat", "DataAPI", "Future", "InlineStrings", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrettyTables", "Printf", "REPL", "Random", "Reexport", "SentinelArrays", "SnoopPrecompile", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "aa51303df86f8626a962fccb878430cdb0a97eee"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.5.0"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "d1fff3a548102f48987a52a2e0d114fa97d730f0"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.13"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.Dictionaries]]
deps = ["Indexing", "Random", "Serialization"]
git-tree-sha1 = "e82c3c97b5b4ec111f3c1b55228cebc7510525a2"
uuid = "85a47980-9c8c-11e8-2b9f-f7ca1fa99fb4"
version = "0.3.25"

[[deps.Distances]]
deps = ["LinearAlgebra", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "49eba9ad9f7ead780bfb7ee319f962c811c6d3b2"
uuid = "b4f34e82-e78d-54a5-968a-f98e89d6e8f7"
version = "0.10.8"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.Distributions]]
deps = ["FillArrays", "LinearAlgebra", "PDMats", "Printf", "QuadGK", "Random", "SparseArrays", "SpecialFunctions", "Statistics", "StatsBase", "StatsFuns", "Test"]
git-tree-sha1 = "180538ef4e3aa02b01413055a7a9e8b6047663e1"
uuid = "31c24e10-a181-5473-b8eb-7969acd0382f"
version = "0.25.88"

    [deps.Distributions.extensions]
    DistributionsChainRulesCoreExt = "ChainRulesCore"
    DistributionsDensityInterfaceExt = "DensityInterface"

    [deps.Distributions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    DensityInterface = "b429d917-457f-4dbc-8f4c-0cc954292b1d"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "2fb1e02f2b635d0845df5d7c167fec4dd739b00d"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.3"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.DualNumbers]]
deps = ["Calculus", "NaNMath", "SpecialFunctions"]
git-tree-sha1 = "5837a837389fccf076445fce071c8ddaea35a566"
uuid = "fa6b7ba4-c1ee-5f82-b5fc-ecf0adba8f74"
version = "0.6.8"

[[deps.EarCut_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e3290f2d49e661fbd94046d7e3726ffcb2d41053"
uuid = "5ae413db-bbd1-5e63-b57d-d24a61df00f5"
version = "2.2.4+0"

[[deps.Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "bad72f730e9e91c08d9427d5e8db95478a3c323d"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.4.8+0"

[[deps.Extents]]
git-tree-sha1 = "5e1e4c53fa39afe63a7d356e30452249365fba99"
uuid = "411431e0-e8b7-467b-b5e0-f676ba4f2910"
version = "0.1.1"

[[deps.FFMPEG]]
deps = ["FFMPEG_jll"]
git-tree-sha1 = "b57e3acbe22f8484b4b5ff66a7499717fe1a9cc8"
uuid = "c87230d0-a227-11e9-1b43-d7ebe4e7570a"
version = "0.4.1"

[[deps.FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "PCRE2_jll", "Pkg", "Zlib_jll", "libaom_jll", "libass_jll", "libfdk_aac_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "74faea50c1d007c85837327f6775bea60b5492dd"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "4.4.2+2"

[[deps.FFTW]]
deps = ["AbstractFFTs", "FFTW_jll", "LinearAlgebra", "MKL_jll", "Preferences", "Reexport"]
git-tree-sha1 = "f9818144ce7c8c41edf5c4c179c684d92aa4d9fe"
uuid = "7a1cc6ca-52ef-59f5-83cd-3a7055c09341"
version = "1.6.0"

[[deps.FFTW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c6033cc3892d0ef5bb9cd29b7f2f0331ea5184ea"
uuid = "f5851436-0d7a-5f13-b9de-f02708fd171a"
version = "3.3.10+0"

[[deps.FileIO]]
deps = ["Pkg", "Requires", "UUIDs"]
git-tree-sha1 = "7be5f99f7d15578798f338f5433b6c432ea8037b"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.16.0"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.FillArrays]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "Statistics"]
git-tree-sha1 = "fc86b4fd3eff76c3ce4f5e96e2fdfa6282722885"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "1.0.0"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[deps.Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "21efd19106a55620a188615da6d3d06cd7f6ee03"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.13.93+0"

[[deps.Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[deps.FreeType]]
deps = ["CEnum", "FreeType2_jll"]
git-tree-sha1 = "cabd77ab6a6fdff49bfd24af2ebe76e6e018a2b4"
uuid = "b38be410-82b0-50bf-ab77-7b57e271db43"
version = "4.0.0"

[[deps.FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "87eb71354d8ec1a96d4a7636bd57a7347dde3ef9"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.10.4+0"

[[deps.FreeTypeAbstraction]]
deps = ["ColorVectorSpace", "Colors", "FreeType", "GeometryBasics"]
git-tree-sha1 = "38a92e40157100e796690421e34a11c107205c86"
uuid = "663a7486-cb36-511b-a19d-713bb74d65c9"
version = "0.10.0"

[[deps.FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "aa31987c2ba8704e23c6c8ba8a4f769d5d7e4f91"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.10+0"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.GLM]]
deps = ["Distributions", "LinearAlgebra", "Printf", "Reexport", "SparseArrays", "SpecialFunctions", "Statistics", "StatsAPI", "StatsBase", "StatsFuns", "StatsModels"]
git-tree-sha1 = "cd3e314957dc11c4c905d54d1f5a65c979e4748a"
uuid = "38e38edf-8417-5370-95a0-9cbb8c7f171a"
version = "1.8.2"

[[deps.GPUArraysCore]]
deps = ["Adapt"]
git-tree-sha1 = "1cd7f0af1aa58abc02ea1d872953a97359cb87fa"
uuid = "46192b85-c4d5-4398-a991-12ede77f4527"
version = "0.1.4"

[[deps.GeoInterface]]
deps = ["Extents"]
git-tree-sha1 = "0eb6de0b312688f852f347171aba888658e29f20"
uuid = "cf35fbd7-0cd7-5166-be24-54bfbe79505f"
version = "1.3.0"

[[deps.GeometryBasics]]
deps = ["EarCut_jll", "GeoInterface", "IterTools", "LinearAlgebra", "StaticArrays", "StructArrays", "Tables"]
git-tree-sha1 = "659140c9375afa2f685e37c1a0b9c9a60ef56b40"
uuid = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
version = "0.4.7"

[[deps.Gettext_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "9b02998aba7bf074d14de89f9d37ca24a1a0b046"
uuid = "78b55507-aeef-58d4-861c-77aaff3498b1"
version = "0.21.0+0"

[[deps.Glib_jll]]
deps = ["Artifacts", "Gettext_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE2_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "d3b3624125c1474292d0d8ed0f65554ac37ddb23"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.74.0+2"

[[deps.Graphics]]
deps = ["Colors", "LinearAlgebra", "NaNMath"]
git-tree-sha1 = "d61890399bc535850c4bf08e4e0d3a7ad0f21cbd"
uuid = "a2bd30eb-e257-5431-a919-1863eab51364"
version = "1.1.2"

[[deps.Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "344bf40dcab1073aca04aa0df4fb092f920e4011"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.14+0"

[[deps.GridLayoutBase]]
deps = ["GeometryBasics", "InteractiveUtils", "Observables"]
git-tree-sha1 = "678d136003ed5bceaab05cf64519e3f956ffa4ba"
uuid = "3955a311-db13-416c-9275-1d80ed98e5e9"
version = "0.9.1"

[[deps.Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[deps.HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg"]
git-tree-sha1 = "129acf094d168394e80ee1dc4bc06ec835e510a3"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "2.8.1+1"

[[deps.HypergeometricFunctions]]
deps = ["DualNumbers", "LinearAlgebra", "OpenLibm_jll", "SpecialFunctions"]
git-tree-sha1 = "432b5b03176f8182bd6841fbfc42c718506a2d5f"
uuid = "34004b35-14d8-5ef3-9330-4cdb6864b03a"
version = "0.3.15"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "8d511d5b81240fc8e6802386302675bdf47737b9"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.4"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "c47c5fa4c5308f27ccaac35504858d8914e102f9"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.4"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "f7be53659ab06ddc986428d3a9dcc95f6fa6705a"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.2"

[[deps.ImageAxes]]
deps = ["AxisArrays", "ImageBase", "ImageCore", "Reexport", "SimpleTraits"]
git-tree-sha1 = "c54b581a83008dc7f292e205f4c409ab5caa0f04"
uuid = "2803e5a7-5153-5ecf-9a86-9b4c37f5f5ac"
version = "0.6.10"

[[deps.ImageBase]]
deps = ["ImageCore", "Reexport"]
git-tree-sha1 = "b51bb8cae22c66d0f6357e3bcb6363145ef20835"
uuid = "c817782e-172a-44cc-b673-b171935fbb9e"
version = "0.1.5"

[[deps.ImageCore]]
deps = ["AbstractFFTs", "ColorVectorSpace", "Colors", "FixedPointNumbers", "Graphics", "MappedArrays", "MosaicViews", "OffsetArrays", "PaddedViews", "Reexport"]
git-tree-sha1 = "acf614720ef026d38400b3817614c45882d75500"
uuid = "a09fc81d-aa75-5fe9-8630-4744c3626534"
version = "0.9.4"

[[deps.ImageIO]]
deps = ["FileIO", "IndirectArrays", "JpegTurbo", "LazyModules", "Netpbm", "OpenEXR", "PNGFiles", "QOI", "Sixel", "TiffImages", "UUIDs"]
git-tree-sha1 = "342f789fd041a55166764c351da1710db97ce0e0"
uuid = "82e4d734-157c-48bb-816b-45c225c6df19"
version = "0.6.6"

[[deps.ImageMetadata]]
deps = ["AxisArrays", "ImageAxes", "ImageBase", "ImageCore"]
git-tree-sha1 = "36cbaebed194b292590cba2593da27b34763804a"
uuid = "bc367c6b-8a6b-528e-b4bd-a4b897500b49"
version = "0.9.8"

[[deps.Imath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "3d09a9f60edf77f8a4d99f9e015e8fbf9989605d"
uuid = "905a6f67-0a94-5f89-b386-d35d92009cd1"
version = "3.1.7+0"

[[deps.Indexing]]
git-tree-sha1 = "ce1566720fd6b19ff3411404d4b977acd4814f9f"
uuid = "313cdc1a-70c2-5d6a-ae34-0150d3930a38"
version = "1.1.1"

[[deps.IndirectArrays]]
git-tree-sha1 = "012e604e1c7458645cb8b436f8fba789a51b257f"
uuid = "9b13fd28-a010-5f03-acff-a1bbcff69959"
version = "1.0.0"

[[deps.Inflate]]
git-tree-sha1 = "5cd07aab533df5170988219191dfad0519391428"
uuid = "d25df0c9-e2be-5dd7-82c8-3ad0b3e990b9"
version = "0.1.3"

[[deps.InlineStrings]]
deps = ["Parsers"]
git-tree-sha1 = "9cc2baf75c6d09f9da536ddf58eb2f29dedaf461"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.4.0"

[[deps.IntelOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "0cb9352ef2e01574eeebdb102948a58740dcaf83"
uuid = "1d5cc7b8-4909-519e-a0f8-d0f5ad9712d0"
version = "2023.1.0+0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.Interpolations]]
deps = ["Adapt", "AxisAlgorithms", "ChainRulesCore", "LinearAlgebra", "OffsetArrays", "Random", "Ratios", "Requires", "SharedArrays", "SparseArrays", "StaticArrays", "WoodburyMatrices"]
git-tree-sha1 = "721ec2cf720536ad005cb38f50dbba7b02419a15"
uuid = "a98d9a8b-a2ab-59e6-89dd-64a1c18fca59"
version = "0.14.7"

[[deps.IntervalSets]]
deps = ["Dates", "Random", "Statistics"]
git-tree-sha1 = "16c0cc91853084cb5f58a78bd209513900206ce6"
uuid = "8197267c-284f-5f27-9208-e0e47529a953"
version = "0.7.4"

[[deps.InvertedIndices]]
git-tree-sha1 = "0dc7b50b8d436461be01300fd8cd45aa0274b038"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.3.0"

[[deps.IrrationalConstants]]
git-tree-sha1 = "630b497eafcc20001bba38a4651b327dcfc491d2"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.2.2"

[[deps.Isoband]]
deps = ["isoband_jll"]
git-tree-sha1 = "f9b6d97355599074dc867318950adaa6f9946137"
uuid = "f1662d9f-8043-43de-a69a-05efc1cc6ff4"
version = "0.1.1"

[[deps.IterTools]]
git-tree-sha1 = "fa6287a4469f5e048d763df38279ee729fbd44e5"
uuid = "c8e1da08-722c-5040-9ed9-7db0dc04731e"
version = "1.4.0"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "abc9885a7ca2052a736a600f7fa66209f96506e1"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.4.1"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "31e996f0a15c7b280ba9f76636b3ff9e2ae58c9a"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.4"

[[deps.JpegTurbo]]
deps = ["CEnum", "FileIO", "ImageCore", "JpegTurbo_jll", "TOML"]
git-tree-sha1 = "106b6aa272f294ba47e96bd3acbabdc0407b5c60"
uuid = "b835a17e-a41a-41e7-81f0-2f016b05efe0"
version = "0.1.2"

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "6f2675ef130a300a112286de91973805fcc5ffbc"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "2.1.91+0"

[[deps.KernelDensity]]
deps = ["Distributions", "DocStringExtensions", "FFTW", "Interpolations", "StatsBase"]
git-tree-sha1 = "4a9513ad756e712177bd342ba6c022b515ed8d76"
uuid = "5ab0869b-81aa-558d-bb23-cbf5423bbe9b"
version = "0.6.6"

[[deps.LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "f6250b16881adf048549549fba48b1161acdac8c"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.1+0"

[[deps.LZO_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e5b909bcf985c5e2605737d2ce278ed791b89be6"
uuid = "dd4b983a-f0e5-5f8d-a1b7-129d4a5fb1ac"
version = "2.10.1+0"

[[deps.LaTeXStrings]]
git-tree-sha1 = "f2355693d6778a178ade15952b7ac47a4ff97996"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.0"

[[deps.LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"

[[deps.LazyModules]]
git-tree-sha1 = "a560dd966b386ac9ae60bdd3a3d3a326062d3c3e"
uuid = "8cdb02fc-e678-4876-92c5-9defec4f444e"
version = "0.3.1"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.3"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "7.84.0+0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.10.2+0"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.Libffi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "0b4a5d71f3e5200a7dff793393e09dfc2d874290"
uuid = "e9f186c6-92d2-5b65-8a66-fee21dc1b490"
version = "3.2.2+1"

[[deps.Libgcrypt_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgpg_error_jll", "Pkg"]
git-tree-sha1 = "64613c82a59c120435c067c2b809fc61cf5166ae"
uuid = "d4300ac3-e22c-5743-9152-c294e39db1e4"
version = "1.8.7+0"

[[deps.Libgpg_error_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c333716e46366857753e273ce6a69ee0945a6db9"
uuid = "7add5ba3-2f88-524e-9cd5-f83b8a55f7b8"
version = "1.42.0+0"

[[deps.Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c7cb1f5d892775ba13767a87c7ada0b980ea0a71"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.16.1+2"

[[deps.Libmount_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9c30530bf0effd46e15e0fdcf2b8636e78cbbd73"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.35.0+0"

[[deps.Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "7f3efec06033682db852f8b3bc3c1d2b0a0ab066"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.36.0+0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.Loess]]
deps = ["Distances", "LinearAlgebra", "Statistics"]
git-tree-sha1 = "46efcea75c890e5d820e670516dc156689851722"
uuid = "4345ca2d-374a-55d4-8d30-97f9976e7612"
version = "0.5.4"

[[deps.LogExpFunctions]]
deps = ["DocStringExtensions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "0a1b7c2863e44523180fdb3146534e265a91870b"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.23"

    [deps.LogExpFunctions.extensions]
    LogExpFunctionsChainRulesCoreExt = "ChainRulesCore"
    LogExpFunctionsChangesOfVariablesExt = "ChangesOfVariables"
    LogExpFunctionsInverseFunctionsExt = "InverseFunctions"

    [deps.LogExpFunctions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    ChangesOfVariables = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.MIMEs]]
git-tree-sha1 = "65f28ad4b594aebe22157d6fac869786a255b7eb"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "0.1.4"

[[deps.MKL_jll]]
deps = ["Artifacts", "IntelOpenMP_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "Pkg"]
git-tree-sha1 = "2ce8695e1e699b68702c03402672a69f54b8aca9"
uuid = "856f044c-d86e-5d09-b602-aeab76dc8ba7"
version = "2022.2.0+0"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "42324d08725e200c23d4dfb549e0d5d89dede2d2"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.10"

[[deps.Makie]]
deps = ["Animations", "Base64", "ColorBrewer", "ColorSchemes", "ColorTypes", "Colors", "Contour", "Distributions", "DocStringExtensions", "Downloads", "FFMPEG", "FileIO", "FixedPointNumbers", "Formatting", "FreeType", "FreeTypeAbstraction", "GeometryBasics", "GridLayoutBase", "ImageIO", "InteractiveUtils", "IntervalSets", "Isoband", "KernelDensity", "LaTeXStrings", "LinearAlgebra", "MakieCore", "Markdown", "Match", "MathTeXEngine", "MiniQhull", "Observables", "OffsetArrays", "Packing", "PlotUtils", "PolygonOps", "Printf", "Random", "RelocatableFolders", "Setfield", "Showoff", "SignedDistanceFields", "SnoopPrecompile", "SparseArrays", "StableHashTraits", "Statistics", "StatsBase", "StatsFuns", "StructArrays", "TriplotBase", "UnicodeFun"]
git-tree-sha1 = "74657542dc85c3b72b8a5a9392d57713d8b7a999"
uuid = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"
version = "0.19.4"

[[deps.MakieCore]]
deps = ["Observables"]
git-tree-sha1 = "9926529455a331ed73c19ff06d16906737a876ed"
uuid = "20f20a25-4f0e-4fdf-b5d1-57303727442b"
version = "0.6.3"

[[deps.MappedArrays]]
git-tree-sha1 = "e8b359ef06ec72e8c030463fe02efe5527ee5142"
uuid = "dbb5928d-eab1-5f90-85c2-b9b0edb7c900"
version = "0.4.1"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.Match]]
git-tree-sha1 = "1d9bc5c1a6e7ee24effb93f175c9342f9154d97f"
uuid = "7eb4fadd-790c-5f42-8a69-bfa0b872bfbf"
version = "1.2.0"

[[deps.MathTeXEngine]]
deps = ["AbstractTrees", "Automa", "DataStructures", "FreeTypeAbstraction", "GeometryBasics", "LaTeXStrings", "REPL", "RelocatableFolders", "Test", "UnicodeFun"]
git-tree-sha1 = "8f52dbaa1351ce4cb847d95568cb29e62a307d93"
uuid = "0a4f8689-d25c-4efe-a92b-7142dfc1aa53"
version = "0.5.6"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.2+0"

[[deps.MiniQhull]]
deps = ["QhullMiniWrapper_jll"]
git-tree-sha1 = "9dc837d180ee49eeb7c8b77bb1c860452634b0d1"
uuid = "978d7f02-9e05-4691-894f-ae31a51d76ca"
version = "0.4.0"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "f66bdc5de519e8f8ae43bdc598782d35a25b1272"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.1.0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MosaicViews]]
deps = ["MappedArrays", "OffsetArrays", "PaddedViews", "StackViews"]
git-tree-sha1 = "7b86a5d4d70a9f5cdf2dacb3cbe6d251d1a61dbe"
uuid = "e94cdb99-869f-56ef-bcf0-1ae2bcbe0389"
version = "0.3.4"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2022.10.11"

[[deps.NaNMath]]
deps = ["OpenLibm_jll"]
git-tree-sha1 = "0877504529a3e5c3343c6f8b4c0381e57e4387e4"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "1.0.2"

[[deps.Netpbm]]
deps = ["FileIO", "ImageCore", "ImageMetadata"]
git-tree-sha1 = "5ae7ca23e13855b3aba94550f26146c01d259267"
uuid = "f09324ee-3d7c-5217-9330-fc30815ba969"
version = "1.1.0"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.Observables]]
git-tree-sha1 = "6862738f9796b3edc1c09d0890afce4eca9e7e93"
uuid = "510215fc-4207-5dde-b226-833fc4488ee2"
version = "0.5.4"

[[deps.OffsetArrays]]
deps = ["Adapt"]
git-tree-sha1 = "82d7c9e310fe55aa54996e6f7f94674e2a38fcb4"
uuid = "6fe1bfb0-de20-5000-8ca7-80f57d26f881"
version = "1.12.9"

[[deps.Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "887579a3eb005446d514ab7aeac5d1d027658b8f"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.5+1"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.21+4"

[[deps.OpenEXR]]
deps = ["Colors", "FileIO", "OpenEXR_jll"]
git-tree-sha1 = "327f53360fdb54df7ecd01e96ef1983536d1e633"
uuid = "52e1d378-f018-4a11-a4be-720524705ac7"
version = "0.3.2"

[[deps.OpenEXR_jll]]
deps = ["Artifacts", "Imath_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "a4ca623df1ae99d09bc9868b008262d0c0ac1e4f"
uuid = "18a262bb-aa17-5467-a713-aee519bc75cb"
version = "3.1.4+0"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.1+0"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9ff31d101d987eb9d66bd8b176ac7c277beccd09"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "1.1.20+0"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[deps.Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "51a08fb14ec28da2ec7a927c4337e4332c2a4720"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.3.2+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "d321bf2de576bf25ec4d3e4360faca399afca282"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.6.0"

[[deps.PCRE2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "efcefdf7-47ab-520b-bdef-62a2eaa19f15"
version = "10.42.0+0"

[[deps.PDMats]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "67eae2738d63117a196f497d7db789821bce61d1"
uuid = "90014a1f-27ba-587c-ab20-58faa44d9150"
version = "0.11.17"

[[deps.PNGFiles]]
deps = ["Base64", "CEnum", "ImageCore", "IndirectArrays", "OffsetArrays", "libpng_jll"]
git-tree-sha1 = "f809158b27eba0c18c269cf2a2be6ed751d3e81d"
uuid = "f57f5aa1-a3ce-4bc8-8ab9-96f992907883"
version = "0.3.17"

[[deps.Packing]]
deps = ["GeometryBasics"]
git-tree-sha1 = "ec3edfe723df33528e085e632414499f26650501"
uuid = "19eb6ba3-879d-56ad-ad62-d5c202156566"
version = "0.5.0"

[[deps.PaddedViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "0fac6313486baae819364c52b4f483450a9d793f"
uuid = "5432bcbf-9aad-5242-b902-cca2824c8663"
version = "0.5.12"

[[deps.Pango_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "FriBidi_jll", "Glib_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "84a314e3926ba9ec66ac097e3635e270986b0f10"
uuid = "36c8627f-9965-5494-a995-c6b170f724f3"
version = "1.50.9+0"

[[deps.Parameters]]
deps = ["OrderedCollections", "UnPack"]
git-tree-sha1 = "34c0e9ad262e5f7fc75b10a9952ca7692cfc5fbe"
uuid = "d96e819e-fc66-5662-9728-84c9c7592b0a"
version = "0.12.3"

[[deps.Parsers]]
deps = ["Dates", "SnoopPrecompile"]
git-tree-sha1 = "478ac6c952fddd4399e71d4779797c538d0ff2bf"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.5.8"

[[deps.Pixman_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b4f5d02549a10e20780a24fce72bea96b6329e29"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.40.1+0"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.9.0"

[[deps.PkgVersion]]
deps = ["Pkg"]
git-tree-sha1 = "f6cf8e7944e50901594838951729a1861e668cb8"
uuid = "eebad327-c553-4316-9ea0-9fa01ccd7688"
version = "0.3.2"

[[deps.PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "PrecompileTools", "Printf", "Random", "Reexport", "Statistics"]
git-tree-sha1 = "f92e1315dadf8c46561fb9396e525f7200cdc227"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.3.5"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "5bb5129fdd62a2bbbe17c2756932259acf467386"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.50"

[[deps.PolygonOps]]
git-tree-sha1 = "77b3d3605fc1cd0b42d95eba87dfcd2bf67d5ff6"
uuid = "647866c9-e3ac-4575-94e7-e3d426903924"
version = "0.1.2"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "a6062fe4063cdafe78f4a0a81cfffb89721b30e7"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.2"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "2e47054ffe7d0a8872e977c0d09eb4b3d162ebde"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.0.2"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "47e5f437cc0e7ef2ce8406ce1e7e24d44915f88d"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.3.0"

[[deps.PrettyTables]]
deps = ["Crayons", "Formatting", "LaTeXStrings", "Markdown", "Reexport", "StringManipulation", "Tables"]
git-tree-sha1 = "548793c7859e28ef026dba514752275ee871169f"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "2.2.3"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.ProgressMeter]]
deps = ["Distributed", "Printf"]
git-tree-sha1 = "d7a7aef8f8f2d537104f170139553b14dfe39fe9"
uuid = "92933f4c-e287-5a05-a399-4b506db050ca"
version = "1.7.2"

[[deps.QOI]]
deps = ["ColorTypes", "FileIO", "FixedPointNumbers"]
git-tree-sha1 = "18e8f4d1426e965c7b532ddd260599e1510d26ce"
uuid = "4b34888f-f399-49d4-9bb3-47ed5cae4e65"
version = "1.0.0"

[[deps.QhullMiniWrapper_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Qhull_jll"]
git-tree-sha1 = "607cf73c03f8a9f83b36db0b86a3a9c14179621f"
uuid = "460c41e3-6112-5d7f-b78c-b6823adb3f2d"
version = "1.0.0+1"

[[deps.Qhull_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "238dd7e2cc577281976b9681702174850f8d4cbc"
uuid = "784f63db-0788-585a-bace-daefebcd302b"
version = "8.0.1001+0"

[[deps.QuadGK]]
deps = ["DataStructures", "LinearAlgebra"]
git-tree-sha1 = "6ec7ac8412e83d57e313393220879ede1740f9ee"
uuid = "1fd47b50-473d-5c70-9696-f719f8f3bcdc"
version = "2.8.2"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.RangeArrays]]
git-tree-sha1 = "b9039e93773ddcfc828f12aadf7115b4b4d225f5"
uuid = "b3c3ace0-ae52-54e7-9d0b-2c1406fd6b9d"
version = "0.3.2"

[[deps.Ratios]]
deps = ["Requires"]
git-tree-sha1 = "6d7bb727e76147ba18eed998700998e17b8e4911"
uuid = "c84ed2f1-dad5-54f0-aa8e-dbefe2724439"
version = "0.4.4"
weakdeps = ["FixedPointNumbers"]

    [deps.Ratios.extensions]
    RatiosFixedPointNumbersExt = "FixedPointNumbers"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.RelocatableFolders]]
deps = ["SHA", "Scratch"]
git-tree-sha1 = "90bc7a7c96410424509e4263e277e43250c05691"
uuid = "05181044-ff0b-4ac5-8273-598c1e38db00"
version = "1.0.0"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[deps.Rmath]]
deps = ["Random", "Rmath_jll"]
git-tree-sha1 = "f65dcb5fa46aee0cf9ed6274ccbd597adc49aa7b"
uuid = "79098fc4-a85e-5d69-aa6a-4863f24498fa"
version = "0.7.1"

[[deps.Rmath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "6ed52fdd3382cf21947b15e8870ac0ddbff736da"
uuid = "f50d1b31-88e8-58de-be2c-1cc44531875f"
version = "0.4.0+0"

[[deps.Roots]]
deps = ["ChainRulesCore", "CommonSolve", "Printf", "Setfield"]
git-tree-sha1 = "2505d1dcab54520ed5e0a12583f2877f68bec704"
uuid = "f2b01f46-fcfa-551c-844a-d8ac1e96c665"
version = "2.0.13"

    [deps.Roots.extensions]
    RootsForwardDiffExt = "ForwardDiff"
    RootsIntervalRootFindingExt = "IntervalRootFinding"

    [deps.Roots.weakdeps]
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    IntervalRootFinding = "d2bf35a9-74e0-55ec-b149-d360ff49b807"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SIMD]]
deps = ["SnoopPrecompile"]
git-tree-sha1 = "8b20084a97b004588125caebf418d8cab9e393d1"
uuid = "fdea26ae-647d-5447-a871-4b548cad5224"
version = "3.4.4"

[[deps.ScanByte]]
deps = ["Libdl", "SIMD"]
git-tree-sha1 = "2436b15f376005e8790e318329560dcc67188e84"
uuid = "7b38b023-a4d7-4c5e-8d43-3f3097f304eb"
version = "0.3.3"

[[deps.Scratch]]
deps = ["Dates"]
git-tree-sha1 = "30449ee12237627992a99d5e30ae63e4d78cd24a"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.2.0"

[[deps.SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "77d3c4726515dca71f6d80fbb5e251088defe305"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.3.18"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Setfield]]
deps = ["ConstructionBase", "Future", "MacroTools", "StaticArraysCore"]
git-tree-sha1 = "e2cc6d8c88613c05e1defb55170bf5ff211fbeac"
uuid = "efcf1570-3423-57d1-acb7-fd33fddbac46"
version = "1.1.1"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[deps.ShiftedArrays]]
git-tree-sha1 = "503688b59397b3307443af35cd953a13e8005c16"
uuid = "1277b4bf-5013-50f5-be3d-901d8477a67a"
version = "2.0.0"

[[deps.Showoff]]
deps = ["Dates", "Grisu"]
git-tree-sha1 = "91eddf657aca81df9ae6ceb20b959ae5653ad1de"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.0.3"

[[deps.SignedDistanceFields]]
deps = ["Random", "Statistics", "Test"]
git-tree-sha1 = "d263a08ec505853a5ff1c1ebde2070419e3f28e9"
uuid = "73760f76-fbc4-59ce-8f25-708e95d2df96"
version = "0.4.0"

[[deps.SimpleTraits]]
deps = ["InteractiveUtils", "MacroTools"]
git-tree-sha1 = "5d7e3f4e11935503d3ecaf7186eac40602e7d231"
uuid = "699a6c99-e7fa-54fc-8d76-47d257e15c1d"
version = "0.9.4"

[[deps.Sixel]]
deps = ["Dates", "FileIO", "ImageCore", "IndirectArrays", "OffsetArrays", "REPL", "libsixel_jll"]
git-tree-sha1 = "8fb59825be681d451c246a795117f317ecbcaa28"
uuid = "45858cf5-a6b0-47a3-bbea-62219f50df47"
version = "0.1.2"

[[deps.SnoopPrecompile]]
deps = ["Preferences"]
git-tree-sha1 = "e760a70afdcd461cf01a575947738d359234665c"
uuid = "66db9d55-30c0-4569-8b51-7e840670fc0c"
version = "1.0.3"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "a4ada03f999bd01b3a25dcaa30b2d929fe537e00"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.1.0"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.SpecialFunctions]]
deps = ["IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "ef28127915f4229c971eb43f3fc075dd3fe91880"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.2.0"
weakdeps = ["ChainRulesCore"]

    [deps.SpecialFunctions.extensions]
    SpecialFunctionsChainRulesCoreExt = "ChainRulesCore"

[[deps.StableHashTraits]]
deps = ["CRC32c", "Compat", "Dates", "SHA", "Tables", "TupleTools", "UUIDs"]
git-tree-sha1 = "0b8b801b8f03a329a4e86b44c5e8a7d7f4fe10a3"
uuid = "c5dd0088-6c3f-4803-b00e-f31a60c170fa"
version = "0.3.1"

[[deps.StackViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "46e589465204cd0c08b4bd97385e4fa79a0c770c"
uuid = "cae243ae-269e-4f55-b966-ac2d0dc13c15"
version = "0.1.1"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "Random", "StaticArraysCore", "Statistics"]
git-tree-sha1 = "c262c8e978048c2b095be1672c9bee55b4619521"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.5.24"

[[deps.StaticArraysCore]]
git-tree-sha1 = "6b7ba252635a5eff6a0b0664a41ee140a1c9e72a"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.4.0"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.9.0"

[[deps.StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "45a7769a04a3cf80da1c1c7c60caf932e6f4c9f7"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.6.0"

[[deps.StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "d1bf48bfcc554a3761a133fe3a9bb01488e06916"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.33.21"

[[deps.StatsFuns]]
deps = ["HypergeometricFunctions", "IrrationalConstants", "LogExpFunctions", "Reexport", "Rmath", "SpecialFunctions"]
git-tree-sha1 = "f625d686d5a88bcd2b15cd81f18f98186fdc0c9a"
uuid = "4c63d2b9-4356-54db-8cca-17b64c39e42c"
version = "1.3.0"

    [deps.StatsFuns.extensions]
    StatsFunsChainRulesCoreExt = "ChainRulesCore"
    StatsFunsInverseFunctionsExt = "InverseFunctions"

    [deps.StatsFuns.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

[[deps.StatsModels]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "Printf", "REPL", "ShiftedArrays", "SparseArrays", "StatsBase", "StatsFuns", "Tables"]
git-tree-sha1 = "8cc7a5385ecaa420f0b3426f9b0135d0df0638ed"
uuid = "3eaba693-59b7-5ba5-a881-562e759f1c8d"
version = "0.7.2"

[[deps.StringManipulation]]
git-tree-sha1 = "46da2434b41f41ac3594ee9816ce5541c6096123"
uuid = "892a3eda-7b42-436c-8928-eab12a02cf0e"
version = "0.3.0"

[[deps.StructArrays]]
deps = ["Adapt", "DataAPI", "GPUArraysCore", "StaticArraysCore", "Tables"]
git-tree-sha1 = "521a0e828e98bb69042fec1809c1b5a680eb7389"
uuid = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
version = "0.6.15"

[[deps.SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "Pkg", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "5.10.1+6"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "OrderedCollections", "TableTraits", "Test"]
git-tree-sha1 = "1544b926975372da01227b382066ab70e574a3ec"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.10.1"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.TensorCore]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1feb45f88d133a655e001435632f019a9a1bcdb6"
uuid = "62fd8b95-f654-4bbd-a8a5-9c27f68ccd50"
version = "0.1.1"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.TiffImages]]
deps = ["ColorTypes", "DataStructures", "DocStringExtensions", "FileIO", "FixedPointNumbers", "IndirectArrays", "Inflate", "Mmap", "OffsetArrays", "PkgVersion", "ProgressMeter", "UUIDs"]
git-tree-sha1 = "8621f5c499a8aa4aa970b1ae381aae0ef1576966"
uuid = "731e570b-9d59-4bfa-96dc-6df516fadf69"
version = "0.6.4"

[[deps.TranscodingStreams]]
deps = ["Random", "Test"]
git-tree-sha1 = "9a6ae7ed916312b41236fcef7e0af564ef934769"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.9.13"

[[deps.Tricks]]
git-tree-sha1 = "aadb748be58b492045b4f56166b5188aa63ce549"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.7"

[[deps.TriplotBase]]
git-tree-sha1 = "4d4ed7f294cda19382ff7de4c137d24d16adc89b"
uuid = "981d1d27-644d-49a2-9326-4793e63143c3"
version = "0.1.0"

[[deps.TupleTools]]
git-tree-sha1 = "3c712976c47707ff893cf6ba4354aa14db1d8938"
uuid = "9d95972d-f1c8-5527-a6e0-b4b365fa01f6"
version = "1.3.0"

[[deps.URIs]]
git-tree-sha1 = "074f993b0ca030848b897beff716d93aca60f06a"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.4.2"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.UnPack]]
git-tree-sha1 = "387c1f73762231e86e0c9c5443ce3b4a0a9a0c2b"
uuid = "3a884ed6-31ef-47d7-9d2a-63182c4928ed"
version = "1.0.2"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.UnicodeFun]]
deps = ["REPL"]
git-tree-sha1 = "53915e50200959667e78a92a418594b428dffddf"
uuid = "1cfade01-22cf-5700-b092-accc4b62d6e1"
version = "0.4.1"

[[deps.WoodburyMatrices]]
deps = ["LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "de67fa59e33ad156a590055375a30b23c40299d3"
uuid = "efce3f68-66dc-5838-9240-27a6d6f5f9b6"
version = "0.5.5"

[[deps.XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "93c41695bc1c08c46c5899f4fe06d6ead504bb73"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.10.3+0"

[[deps.XSLT_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgcrypt_jll", "Libgpg_error_jll", "Libiconv_jll", "Pkg", "XML2_jll", "Zlib_jll"]
git-tree-sha1 = "91844873c4085240b95e795f692c4cec4d805f8a"
uuid = "aed1982a-8fda-507f-9586-7b0439959a61"
version = "1.1.34+0"

[[deps.Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "5be649d550f3f4b95308bf0183b82e2582876527"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.6.9+4"

[[deps.Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4e490d5c960c314f33885790ed410ff3a94ce67e"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.9+4"

[[deps.Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fe47bd2247248125c428978740e18a681372dd4"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.3+4"

[[deps.Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "b7c0aa8c376b31e4852b360222848637f481f8c3"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.4+4"

[[deps.Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "19560f30fd49f4d4efbe7002a1037f8c43d43b96"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.10+4"

[[deps.Xorg_libpthread_stubs_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "6783737e45d3c59a4a4c4091f5f88cdcf0908cbb"
uuid = "14d82f49-176c-5ed1-bb49-ad3f5cbd8c74"
version = "0.1.0+3"

[[deps.Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "XSLT_jll", "Xorg_libXau_jll", "Xorg_libXdmcp_jll", "Xorg_libpthread_stubs_jll"]
git-tree-sha1 = "daf17f441228e7a3833846cd048892861cff16d6"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.13.0+3"

[[deps.Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "79c31e7844f6ecf779705fbc12146eb190b7d845"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.4.0+3"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+0"

[[deps.isoband_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "51b5eeb3f98367157a7a12a1fb0aa5328946c03c"
uuid = "9a68df92-36a6-505f-a73e-abb412b6bfb4"
version = "0.2.3+0"

[[deps.libaom_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "3a2ea60308f0996d26f1e5354e10c24e9ef905d4"
uuid = "a4ae2306-e953-59d6-aa16-d00cac43593b"
version = "3.4.0+0"

[[deps.libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "5982a94fcba20f02f42ace44b9894ee2b140fe47"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.15.1+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.7.0+0"

[[deps.libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "daacc84a041563f965be61859a36e17c4e4fcd55"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.2+0"

[[deps.libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "94d180a6d2b5e55e447e2d27a29ed04fe79eb30c"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.38+0"

[[deps.libsixel_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Pkg", "libpng_jll"]
git-tree-sha1 = "d4f63314c8aa1e48cd22aa0c17ed76cd1ae48c3c"
uuid = "075b6546-f08a-558a-be8f-8157d0f608a5"
version = "1.10.3+0"

[[deps.libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll", "Pkg"]
git-tree-sha1 = "b910cb81ef3fe6e78bf6acee440bda86fd6ae00c"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.7+1"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.48.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+0"

[[deps.x264_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fea590b89e6ec504593146bf8b988b2c00922b2"
uuid = "1270edf5-f2f9-52d2-97e9-ab00b5d0237a"
version = "2021.5.5+0"

[[deps.x265_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "ee567a171cce03570d77ad3a43e90218e38937a9"
uuid = "dfaa095f-4041-5dcd-9319-2fabd8486b76"
version = "3.5.0+0"
"""

# ╔═╡ Cell order:
# ╟─cdd24518-1cd3-43af-9a88-f0a8cd3cd6ed
# ╟─0edf9214-7213-4b1d-8fa6-54a365525d29
# ╟─c3773842-4fa1-4f80-a8a0-82d4d9ca49bc
# ╟─1c23af35-64f5-4b96-9eab-98ee9b1ecb4c
# ╠═64d44910-988c-4e24-baf6-6408da65bd21
# ╟─ac27dd69-1216-4a02-ba62-ebb098b33fa1
# ╠═3dd0c186-04f0-425c-93dc-825c7d4b606e
# ╟─2289c7a7-3493-4bfb-8ffe-31b074d17b14
# ╟─0caee0bf-77c0-4542-a68e-9052d230ca74
# ╟─38555a5e-5d39-4c61-9381-94c8fb67a257
# ╠═4d7ee33f-ff78-4ea9-838b-a8320df4651f
# ╟─1fbf9f02-7ad2-4ddd-ac2c-92af79c9ed02
# ╟─2e09462e-6030-4e33-bc7a-9d2faed4ca74
# ╠═eb565042-1823-4d5a-b4d1-ee314dccd4e0
# ╟─e5cfdbc2-f592-40bb-ba5d-07f455dd5bd4
# ╠═e1376e99-a636-4d28-b711-2dd4be66374f
# ╠═23a991be-7c8b-45e2-bd75-af5e146fc6b0
# ╠═4de350bb-d2be-46b1-8558-a49f54a29dd1
# ╠═98a7d8e0-1741-4447-b612-e40491fa8673
# ╠═1503b0d4-6d0e-4b5d-896f-e13c093ad3d4
# ╟─deeff3d5-3856-43cb-8469-2a4d6d7fca4f
# ╟─b6101102-2054-4932-b6b6-5070cd84f2be
# ╠═19e28c66-a389-4903-82a5-c963cf0b90b9
# ╠═a8f1dc13-b73c-44b0-8e63-82431f904313
# ╠═bd353706-be2d-480d-8ebb-cf20cab0dbec
# ╟─b26682fb-4b4b-45bc-b406-7a15637f8199
# ╟─505d44ec-1c16-4cc3-851d-a9d7feb18cb3
# ╟─288c66fc-aa44-42d8-b19b-c9725bef2d44
# ╠═d7f08043-fa3e-476c-a25a-dac7c16cc570
# ╟─49d69255-20f3-490d-b068-81ec0cb22ff3
# ╟─ec990221-bff1-41f3-8a94-2ef23a836f2c
# ╟─90d0941c-d952-44c5-8acf-6adf30361b57
# ╟─fe3bf03d-eb60-40d6-aae8-8e85b0bb9213
# ╟─514c081b-5343-4e63-abdf-eda3356c110a
# ╟─612478ce-215b-4020-a2f7-a64818f8fb03
# ╠═ec54c169-f795-40fe-8c5c-b63600834d77
# ╟─9ebdb7e1-c1e3-4e22-8c24-e82e5d927160
# ╠═492aa578-b079-4710-b1e9-2c887922d9f2
# ╠═d4efae22-e989-4d59-b916-ecc6d3c8b0e3
# ╠═d31538cc-4223-47bf-ad19-b1ed9c1ab1f5
# ╠═f29e5256-ccec-4c99-9f90-5f98142b1f40
# ╠═30496b92-df7c-4f48-9983-5cbb99d81f7a
# ╟─f8c3b95f-0895-4301-9eaf-02b238a46ec9
# ╟─d7cbcf7e-a467-4c51-bc9e-9b04aa943e3f
# ╠═f783c67b-5456-43cb-baa7-7812bf797723
# ╟─f8686182-95b7-497d-9b3a-8d272efd9f90
# ╟─86dced4d-2eb3-4f67-835f-3b9b4f247007
# ╠═573757f8-8093-4310-8073-11ae7fcff776
# ╟─bc435feb-ed9f-4662-b023-5eae0f1e778a
# ╠═9349d7cf-ddab-41a8-9ba2-44ea849619b3
# ╠═110ed843-0259-43bc-9e60-189dcd4515b3
# ╠═2d15caf9-986d-4595-ab24-39ada24c9778
# ╠═9f901ed5-0458-4358-a793-a530e397c01f
# ╠═6f18ea5e-5816-4791-974f-78910f393e57
# ╟─e4035abe-11a1-4c2c-8312-4d1c71e2f9ab
# ╟─ab69ab43-99bf-4a92-9698-70e170761e82
# ╟─5c7c3dc0-7848-4431-829e-508664d9c5af
# ╠═b099dbbf-9648-44c5-984c-fdd80ee81469
# ╠═f8fbff0d-15d4-43ca-9f9c-29788ff793ec
# ╠═4894a323-c8c8-4f34-b311-20c64176b89d
# ╠═4bfa5d92-b177-4442-b045-e05cc48b6cc4
# ╠═ebd88b43-e277-4c79-b443-1661a3c438b8
# ╟─fd0fb774-a805-4739-b570-0d2e191a3294
# ╟─eb7bbd16-04d3-4d7d-b4af-e77f89e4180e
# ╟─ae8fd43c-f658-47b1-8781-6f699ade6bdb
# ╟─bd2e4d28-c68b-45c9-b68e-b477b44fcd75
# ╟─264fc65e-d09a-4c67-94de-f845d42d18a3
# ╟─6e607792-e297-483f-8917-c871fa0c26d0
# ╠═0605f7f4-7123-4c1e-a0f6-aefdfeaed25d
# ╠═532d0b24-6ace-4579-bf2a-d12c07ee9436
# ╟─518eec58-eb4b-4294-9090-b6645f51a337
# ╠═5c1387ed-973c-4109-9ace-c473a4efe9ee
# ╠═6f92c837-1760-423e-9777-9db9ad758475
# ╠═563c267e-0c6a-4b90-81a7-fc8ff4c73c75
# ╠═6d5523f2-a517-48df-9f31-bbd516e1208e
# ╠═9fa33ac0-bb2f-4055-b124-8c7c19621226
# ╠═276e171b-271d-4610-b9bb-01b212193123
# ╠═aecea3fe-f0ee-4953-857b-29d6a5640530
# ╠═9353566b-a70e-4dbe-8f02-b16d2c0570d2
# ╠═0b9c3978-0eb9-4f80-b51d-540d4ed88c3e
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
