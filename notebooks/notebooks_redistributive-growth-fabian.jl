### A Pluto.jl notebook ###
# v0.19.5

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ f0765abe-d6d3-11ec-0c46-e909705296dd
md"""
# Redistributive Growth
"""

# ╔═╡ e96bdfab-4bd4-4c79-9478-413efe1014d3
md"""
## Parameters
"""

# ╔═╡ 3a54e974-1f95-4107-8959-642a8d2ea155
Base.@kwdef struct RedistributiveGrowthModel
	v = log # utility of housing
	L̄ = 1 # supply of land
	ϕ = 0.5 # fraction with high human capital
	h̃ = 0.8 # inelastic supply of high-skilled labor
	l̃ = 0.7 # inelastic supply of low-skilled labor
	α = 0.3 # capital share
	ρ = 0.1 # ≈ elasticity of substitution between physical and intangible capital
	η = 0.5 # relative productivity of intangible capital & high-skilled labor
	ε = 0.05 # share of experts
	ω = 0.3 # fraction of intangibles that can be "stolen" by innovators
	ψ = 1/2 # cost for producing intangibles
	A = 30 # productivity
end

# ╔═╡ b529ed26-50c8-452d-b4ae-1939ef8c58d2
function F(K, H, l, h, (; A, η, α, ρ, ϕ)) 
	hh = ϕ * h
	ll = (1-ϕ) * l
	A * (
		η     * (H^α * hh^(1-α))^ρ +
		(1-η) * (K^α * ll^(1-α))^ρ
	)^(1/ρ)
end

# ╔═╡ a739eec7-b301-4536-9473-682245275672
F(K, H, (; l̃, h̃, ϕ, η, α, ρ, A)) = F(K, H, l̃, h̃, (; A, η, α, ρ, ϕ))

# ╔═╡ 11f4d233-ddf0-4e03-84a5-11623ba14d01
F(xx, par) = F(xx..., par)

# ╔═╡ 365af2cb-c595-4435-9c62-4d28d33aa1ec
function get_prices(K, H, mod)
	(; l̃, h̃, ϕ) = mod
	xx = [K, H, l̃, h̃]
	oneplusr, R_H, w, q = ForwardDiff.gradient(x -> F(x, mod), xx)

	Y = F(xx, mod)
	q = q/ϕ # this manual intervention here should not be necessary
	w = w/(1-ϕ) # this manual intervention here should not be necessary
	check = Y - w * (1-ϕ)*l̃ - q * ϕ*h̃ - oneplusr * K - R_H * H #< eps()

	(; check, oneplusr, R_H, w, q, Y)
end

# ╔═╡ d312e74b-b9ad-479c-a3c1-7c7d418d183c
get_prices(1,1, mod0)

# ╔═╡ ba1ba3f4-1b4a-4158-8b50-2398502e8998
md"""
## Solving the steady state using equations
"""

# ╔═╡ 1f00565d-3946-4cb5-95f9-672571b8c170
function solve_analytical_equations(mod)
	function Y_RH(K, H, mod)
		(; α, η, ω, ψ) = mod
		Y = F(K, H, mod) # A.7
		R_H = α * η * Y / H # A.2
		check = H - ω/ψ * R_H # A.3
		(; Y, R_H, check)
	end

	function get_h(K, mod, bracket=(eps(), 10))
		find_zero(H -> Y_RH(K, H, mod).check, bracket) # |> maximum #only
	end
	
	function everything(K, mod)
		(; α, η, ω, L̄, l̃, h̃, ψ) = mod
		H  = get_h(K, mod)
		
		(; Y, R_H) = Y_RH(K, H, mod)

		r = α * (1-η) * Y/K - 1 # A.1
		d = (1-ω) * R_H * H # A.4'
		f = d/r
		f = stock_price_ss((; d, r)) # A.4'
		p = house_price_ss(r, mod) # A.5

		check = (1-α) * Y - (p * L̄ + f + K) # A.6

		(; K, H, Y, R_H, r, f, p, check)
	end

	Ks = find_zeros(K -> everything(K, mod).check, (eps(), 100)) 
	
	map(Ks) do K
		delete(everything(K, mod), :check)
	end |> DataFrame
end

# ╔═╡ b5c3c809-4797-434e-a66b-2cefe1f1be36
md"""
* ``\bar L`` $(@bind L̄1 Slider(0.1:0.3:5.0, default=1.0, show_value=true)) available land
* ``\phi`` $(@bind ϕ1 Slider(0.1:0.1:0.9, default=0.2, show_value=true)) fraction with high human capital
* ``\tilde h`` $(@bind h̃1 Slider(1:1:100, default=50, show_value=true)) inelastic supply of high-skilled labor
* ``\tilde l`` $(@bind l̃1 Slider(0.5:0.5:50, default=12.5, show_value=true)) inelastic supply of low-skilled labor
* ``\alpha`` $(@bind α1 Slider(0.1:0.01:0.9, default=0.33, show_value=true)) capital share
* ``\rho`` $(@bind ρ1 Slider(0.1:0.1:2.0, default=1.7, show_value=true)) elasticity of substitution between physical and intangible capital
* ``\eta`` $(@bind η1 Slider(0.01:0.01:0.95, default=0.45, show_value=true)) relative productivity of intangible capital & high-skilled labor
* ``\varepsilon`` $(@bind ε1 Slider(0.01:0.01:0.2, default=0.05, show_value=true)) share of experts
* ``\omega`` $(@bind ω1 Slider(0.1:0.05:0.9, default=0.55, show_value=true)) fraction of intangibles that can be "stolen" by innovators
* ``\psi`` $(@bind ψ1 Slider(0.1:0.1:2.0, default=1., show_value=true)) cost for producing intangibles
* ``A`` $(@bind A1 Slider(0.1:0.1:5, default=1, show_value=true)) productivity
"""

# ╔═╡ ff0ddbc0-9d7b-492e-add5-031bc07d0d4a
outout = let
	mod = RedistributiveGrowthModel(A = A1, L̄ = L̄1, ψ = ψ1, l̃ = l̃1, h̃ = h̃1, ϕ = ϕ1, η = η1, ε = ε1, ρ = ρ1, α = α1, ω = ω1)

	out1 = solve_analytical_equations(mod)
	
	(; out1, mod)
end

# ╔═╡ 7fcbbab9-6205-4d6e-962a-e24b02737fef
using DataFrameMacros, Chain

# ╔═╡ de5d783c-6cd7-4064-8f15-2b60eda61bdb
function solve_more(solution, mod)
	nt = @subset(solution, :r > 0) |> only |> NamedTuple
	(; K, H, p, f) = nt
	(; q, w) = get_prices(K, H, mod)

	(; q, w, nt...)

	(; l̃, h̃, L̄) = mod
	
	assets_low = w * l̃ - p * L̄
	assets_high = q * h̃ - p * L̄

	(; assets_low, assets_high, p, f, ineq = q/w)
end

# ╔═╡ 67ee0656-a813-4b50-a57b-211b3ba3e2be
solve_more(outout...)

# ╔═╡ 0bd0d100-c5eb-4fc7-a2a2-0a93e83e5d53
md"""
### Helper functions
"""

# ╔═╡ 61e6875b-b9d3-4ffa-8c44-53642bdb03f1
using ForwardDiff

# ╔═╡ 713d34c8-4a45-44dd-9ac7-ef94d6cb2b15
v_prime(L, (; v)) = ForwardDiff.derivative(v, L)

# ╔═╡ 65dd9858-e847-47ed-a700-51bdb53bbacf
house_price_ss(r, mod) = v_prime(mod.L̄, mod) / r

# ╔═╡ af5abc37-84c6-4aac-a5e7-aea1ab3e5848
stock_price_ss((; r, d)) = d / r

# ╔═╡ 999cc543-b87a-4b3c-b39f-4e0c31ff2898
md"""
## Simulation
"""

# ╔═╡ 859d0b3a-bcce-4f61-a1f1-d7b45444209a


# ╔═╡ f9c98149-71e0-423d-b7b0-caeea8168479
md"""
# Digging deeper - It's getting messier below here ;-)
"""

# ╔═╡ fb4bc15c-9ad7-4546-9a8a-06c76a1c4e27
md"""
## Firm

Given prices ``(w_t, q_t, r_t, Q_t)`` the firm's problem is to maximize dividends (profits) ``d_t``.
```math
\begin{align}
d^*_t = &\max_{l, h, K} F(K_t, H_t, l_t, h_t) - w_t l_t - q_t h_t - (1+r_t) K_t - Q_t H_t \\
&\begin{aligned}
\text{s.t. } &H_t = H^*(R_{H,t}) && \text{(from innovators)} \\
& Q_t \geq \omega R_{H,t}        && \text{(IC for innovators)} \\
\end{aligned}
\end{align}
```
In optimum
```math
\begin{align}
w_t &= F_l \\
q_t &= F_h\\
(1+r_t) &= F_K \\
Q_t &= \omega R_{H,t} \\
R_{H,t} &= F_H \quad \text{where exactly does this come from?}\\
d_t &= (1 - \omega)R_{H,t} H_t
\end{align}
```
"""

# ╔═╡ 7a6651d9-7c37-4773-ba02-8db0513e75e7
md"""
### Find the level of tangibles ``H`` given ``K``
"""

# ╔═╡ 51526b20-2654-4dec-908f-17b54f738575
function get_H(K, mod)
	find_zeros(H -> get_H_aux(K, H, mod), (0, 3))
end

# ╔═╡ 0d668039-d550-4f80-a816-1ff788f2ab32
function get_H_aux(K, H, mod)	
	(; R_H) = get_prices(K, H, mod)
	H_new = intangible_capital(R_H, mod)
	
	H - H_new
end

# ╔═╡ 2329e8e6-1dd6-4507-9d5f-77c3d5bb8a52
using Roots

# ╔═╡ a94938a4-2119-4ada-a143-ff15683a796b
function get_K(mod)
	find_zeros(K -> everything_given_K(K, mod).check, (eps(), 10)) |> only
end

# ╔═╡ 3b8d01da-ea17-46ec-b958-b580b0b6b002
get_K(mod0)

# ╔═╡ 2599fc83-6528-454f-94f4-85d56689573b
foo(L, (; pₜ, pₜ₊₁, rₜ₊₁), (; v)) = pₜ - (pₜ₊₁ + ForwardDiff.derivative(v, L))/(1+rₜ₊₁)

# ╔═╡ a34f03d4-e987-4cb1-9a83-106ac70b3db1
prices = (; pₜ = 1.0, pₜ₊₁ = 1.0, rₜ₊₁ = 0.05)

# ╔═╡ e7956e57-bbaf-4d69-abbd-6cac19df0791
using CairoMakie

# ╔═╡ b2b2d669-7be8-4ed5-be73-6b9bff387c9a
md"""
## Innovators

* optimality condition ``H^*(R_H) = \frac{\omega}{\psi} R_H``
"""

# ╔═╡ a727150c-eb49-4cc1-9425-81bab85f9ba5
intangible_capital(R_H, (; ω, ψ)) = ω * R_H / ψ

# ╔═╡ c4478a12-e5b3-4720-a0df-751a3b7b4d22
md"""
## Consumers

Consumers take wages ``y^i_t \in \{\tilde l w_t, \tilde h q_t \}``, prices and dividends ``(p_t, f_t, d_t)`` as given and choose the amount of land ``L``, consumption ``c``, shares ``S`` and debt ``D``. ``y_{t+1}`` is non-zero for innovators only.

``(y_t, p_t, r_t, f_t, d_t) \mapsto (L, c, S, D)``

```math
\begin{align}
&\max_{c_{t+1}, L_t, S_t, D_t} c_{t+1} + v(L_t) \\
&\begin{aligned} \text{s.t. }
&p_t L_t + f_t S_t + D_t \leq y^i_t \\
&c_{t+1} \leq y^i_{t+1} + p_{t+1} L_t + (f_{t+1} + d_{t+1})S_t + (1+r_{t+1})D_t \\
&c_{t+1}, L_t, S_t \geq 0
\end{aligned}
\end{align}
```

The first order conditions are

```math
\begin{align}
p_t &= \frac{p_{t+1} + v'(L_t)}{1 + r_{t+1}} \\
f_t &= \frac{f_{t+1} + d_t}{1 + r_{t+1}}
\end{align}
```

The first one gives the optimal amount of land (``L_t``), the second one makes sure that the agent indifferent between the two assets. Thus, only the total investment matters for the agent.

```math
\tilde D_t :=\underbrace{D_t + f_t S_t}_{\text{net savings}} = y_t - p_t L_t
```


"""

# ╔═╡ e7e22e88-078d-48c6-aa43-375429ae8e69
md"""
#### Simplified consumers problem (in terms of net savings ``\tilde D``)
```math
\begin{align}
&\max_{c_{t+1}, L_t, \tilde D_t} c_{t+1} + v(L_t) \\
&\begin{aligned} \text{s.t. }
&p_t L_t + \tilde D_t = y^i_t \\
&c_{t+1} = y^i_{t+1} + p_{t+1} L_t + (1+r_{t+1})\tilde D_t \\
&c_{t+1}, L_t \geq 0
\end{aligned}
\end{align}
```

In optimum ``(p_t, r_t, y_t) \mapsto (\tilde D_t)``
```math
\begin{align}
p_t &= \frac{p_{t+1} + v'(L^*_t)}{1 + r_{t+1}} \\
\tilde D^*_t &= y_i^t - p_t L^*_t \\
c^*_{t+1} &= y^*_{t+1} + p_{t+1} L^*_t + (1+r_{t+1})\tilde D^*_t 
\end{align}
```
"""

# ╔═╡ e1e9fded-7a71-4c8f-9dc3-03644597a654
md"""
#### Aggregate consumers

The total net saving is total income minus total land purchases

``\tilde D^\text{agg} = w_t \tilde l_t + q_t \tilde h_t - p_t \bar L``

(this uses that total land is fixed and that consumers supply labor inelastically)

We know that the labor share ``(1-\alpha)`` is split between high skilled and low skilled labor.

``(1-\alpha) Y_t = (1 - \phi) w_t \tilde l + \phi q_t \tilde h``
"""

# ╔═╡ 154a532c-0864-413e-9593-cdbf624b90fb
md"""
## Equilibrium

* Market clearing ``l = \tilde l``, ``h = \tilde h``
* Innovators ``R_H \mapsto H``
* Firm maximization ``(w, q, r, H, R_H) \mapsto (l, h, K, d)``
* Workers ``() \mapsto ``
"""

# ╔═╡ 6db3164e-6e62-4e04-aa3b-4dfab1bb0065
@bind K Slider(-10:0.1:10, default = 1, show_value = true)

# ╔═╡ fb7d5518-1ae6-4a16-b35a-954306ed94dc
function everything_given_K(K, mod)
	(; ω, L̄, α) = mod
	#K = 5.0

	H = get_H(K, mod) |> only

	(; oneplusr, R_H, w, q, Y) = get_prices(K, H, mod)
	
	d = (1-ω) * R_H * H

	r = oneplusr - 1
	#(; K, H, d, r)

	d = (1-ω) * R_H * H
	f = stock_price_ss((; d, r))
	p = house_price_ss(r, mod)

	lhs = (1-α) * Y - p * L̄
	rhs = K + f

	check = lhs - rhs
	
	(; lhs, rhs, r, f, K, p, H, d, q, w, check)
end

# ╔═╡ 42aa25ec-16fc-4bdf-9341-dc1296d6826a
using DataFrames

# ╔═╡ 1efe99f4-a6d6-4994-a9a5-ba50e4247e1f
df = map(1.0:0.01:2.0) do K
	everything_given_K(K, mod0)
end |> DataFrame

# ╔═╡ 0da88cb6-44ed-4129-af28-26fd67643874
mod0 = mod = RedistributiveGrowthModel(ψ = 0.5, ϕ = 0.1, η = 0.6, ε = 0.01, ρ = 0.0001)
#RedistributiveGrowthModel(ψ = 0.5, η = 0.5, ε = 0.1)

# ╔═╡ 53585d7f-d466-41df-9213-b07265c9571a
begin
	fig = Figure()
	ax = Axis(fig[1,1])

	lines!(ax, df.K, df.lhs, label = "lhs")
 	lines!(ax, df.K, df.rhs, label = "rhs")

	lines(fig[1,2], df.K, df.r)
	lines(fig[2,1], df.K, df.p) #df.q ./ df.w)
	lines(fig[2,2], df.K, df.H)
	axislegend(ax)
	
	fig
end

# ╔═╡ ab8778fc-065e-4ba9-aeb3-dfe86e0f6ca5
house_price_ss(-0.1, mod0)

# ╔═╡ 13f0b6e2-cb6a-48f2-b0dc-fb942a5f948a
let
	(; η, l̃, h̃, ϕ) = mod0

	ineq = η/(1-η) * l̃/h̃ * (1-ϕ)/ϕ
end

# ╔═╡ a2d4bf8e-cad5-4d78-bbbf-edd34e470ccb
using NamedTupleTools

# ╔═╡ 37560b71-5888-41b5-b0b7-2e477e64d80e
md"""
# Adapting Yasmine's Code: Solving stuff backwards
"""

# ╔═╡ 3df41f6a-0c86-4306-8a5d-eab208c717c2
Base.@kwdef struct Yasmine
	v = log # utility of housing
	A=1
	beta = 1
	L_0 = 1
	omega = 1
	h = 24.438
	l = 15.945
	eta_0 = 0.6
	eta_end = 0.8
	alpha = 0.3
	phi = 0.3
	# End Capital
	H26_end = 1.588
	K26_end = 2.840
end

# ╔═╡ 13a7d8d2-9d3e-452e-99ea-605e0e91b589
function output26(H26, K26, eta26, (; h, l, A, alpha))
	output(H26, K26, h, l, (; η = eta26, α = alpha, A))
end

# ╔═╡ f82b306c-338c-4a4b-88d7-86fa9aa846a1
output(H, K, h, l, (; A, η, α)) = A*(H^α * h^(1-α))^η * (K^α * l^(1-α))^(1 - η)

# ╔═╡ 2ea0f7cc-73c5-4f78-b490-878ce3e5f341
function prices26(H, K, η, (; h, l, A, alpha))
	xs = [H, K, h, l]
	par = (; A, α = alpha, η)
	prices = ForwardDiff.gradient(x -> output(x..., par), xs)
	
	R, rp1, q, w = prices
	(; R, rp1, q, w)
end

# ╔═╡ d3c43f6c-7bfd-4b3c-b0b9-9adac24a31ae
let
	(; H26_end, K26_end, h, l, A, eta_end, alpha) = par26
	prices26(H26_end, K26_end, eta_end, par26)
end

# ╔═╡ 4614d327-09be-494c-8284-c90dd254cdb3
begin
	# intangible_capital
	g26(Y26, p26, L26, e26, (; alpha)) = (1 - alpha) * Y26 - p26 * L26 - e26
	intang_cap26(eta26, Y26, (; alpha, beta, omega)) =
		√(alpha * beta * eta26 * Y26/omega)*(omega/beta)
end

# ╔═╡ 787d3365-a764-4f07-9aed-78d601b70aaf
par26 = Yasmine()

# ╔═╡ a8e926c2-4187-4ec8-85f6-14c8179a3eb8
out = let
	(; H26_end, K26_end, eta_end, alpha, omega, L_0) = par26

	keys = (:Y26, :H26, :K26, :r26, :R26, :w26, :q26, :RH26, :div26, :e26, :L26, :p26, :m26, :eta26)
	nt = NamedTuple{keys}(tuple(fill(1.0, length(keys))...))
	NT = typeof((; t = 1, nt...))

	outt = NT[]

	T = 10
	ηs = [
		fill(par26.eta_0, 2T);
		range(par26.eta_0, par26.eta_end, T);
		fill(par26.eta_end, 2T)
	]

	# Initialization
	H26 = H26_end
	K26 = K26_end
	eta26 = ηs[end]

	Y26 = output26(H26, K26, eta26, par26)
	r26 = (alpha*(1-eta26)*Y26/K26)

	Lnext = par26.L_0
	pnext = v_prime(Lnext, par26)/r26
	
	for t ∈ length(ηs):-1:1
	 	eta26 = ηs[t]

		# if you interpret this as a transition path,
		# Y26 and H26 need to be consistent in each period
		# (=> iterate a few times until convergence)
		for it ∈ 1:20
			Y26 = output26(H26, K26, eta26, par26)
	    	H26_new = intang_cap26(eta26, Y26, par26)
			if H26_new ≈ H26
				@info it
				break
			else
				H26 = H26_new
			end
		end
		(; R, rp1, q, w) = prices26(H26, K26, eta26, par26)
		
	    #r26 = (alpha*(1-eta26)*Y26/K26) # 1 + r
	    #R26 = alpha*(eta26)*Y26/H26
	    #w26 = (1-alpha)*(1-eta26)*Y26/par26.l
	    #q26 = (1-alpha)*(eta26)*Y26/par26.h

		r26 = rp1 ## should be rp1 - 1 
		R26 = R
		q26 = q
		w26 = w
		
	    RH26 = R26*H26
	 
		div26 = (1-omega)*RH26
	    e26 = div26/r26
		L26 = Lnext # constant
	    K26 = g26(Y26, pnext, Lnext, e26, par26)
	    p26 = (pnext + v_prime(Lnext, par26))/(1 + r26)
	    m26 = max(0, (1-par26.phi)*p26*L26 - (1-par26.alpha)*(1-eta26)*Y26)
		
	    #eta26 = eta26 - (eta_end-par26.eta_0)/(T)
		
	    # Appending
		push!(outt, (; t, Y26, H26, K26, r26, R26, w26, q26, RH26, div26, e26, L26, p26, m26, eta26))

		pnext = p26
	end
	outt
end |> DataFrame

# ╔═╡ eddb517b-685f-494c-979e-4d6773593268
using AlgebraOfGraphics

# ╔═╡ f0233537-0fd8-4ae6-bd22-bb4c9bae5813
@chain out begin
	DataFrame
	stack(Not(:t))
	data(_) * mapping(:t, :value, layout = :variable) * visual(Lines)
	draw(facet = (linkyaxes = false,))
end

# ╔═╡ 2cdd1dd3-f2ef-4532-a91a-6df387954c5e
md"""
# Appendix
"""

# ╔═╡ d3974a05-fd05-467e-a575-95cea4afa6cd
using PlutoUI: Slider, TableOfContents

# ╔═╡ fbd39ec2-7cd5-4e2e-8547-4a55842b395b
TableOfContents()

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
AlgebraOfGraphics = "cbdf2221-f076-402e-a563-3d30da359d67"
CairoMakie = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"
Chain = "8be319e6-bccf-4806-a6f7-6fae938471bc"
DataFrameMacros = "75880514-38bc-4a95-a458-c2aea5a3a702"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
NamedTupleTools = "d9ec5142-1e00-5aa0-9d6a-321866360f50"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Roots = "f2b01f46-fcfa-551c-844a-d8ac1e96c665"

[compat]
AlgebraOfGraphics = "~0.6.7"
CairoMakie = "~0.8.2"
Chain = "~0.4.10"
DataFrameMacros = "~0.2.1"
DataFrames = "~1.3.4"
ForwardDiff = "~0.10.29"
NamedTupleTools = "~0.14.0"
PlutoUI = "~0.7.38"
Roots = "~2.0.1"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.7.2"
manifest_format = "2.0"

[[deps.AbstractFFTs]]
deps = ["ChainRulesCore", "LinearAlgebra"]
git-tree-sha1 = "6f1d9bc1c08f9f4a8fa92e3ea3cb50153a1b40d4"
uuid = "621f4979-c628-5d54-868e-fcf4e3e8185c"
version = "1.1.0"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "8eaf9f1b4921132a4cff3f36a1d9ba923b14a481"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.1.4"

[[deps.AbstractTrees]]
git-tree-sha1 = "03e0550477d86222521d254b741d470ba17ea0b5"
uuid = "1520ce14-60c1-5f80-bbc7-55ef81b5835c"
version = "0.3.4"

[[deps.Adapt]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "af92965fb30777147966f58acb05da51c5616b5f"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "3.3.3"

[[deps.AlgebraOfGraphics]]
deps = ["Colors", "Dates", "Dictionaries", "FileIO", "GLM", "GeoInterface", "GeometryBasics", "GridLayoutBase", "KernelDensity", "Loess", "Makie", "PlotUtils", "PooledArrays", "RelocatableFolders", "StatsBase", "StructArrays", "Tables"]
git-tree-sha1 = "593a7a5edf41bdc4f29c45446245a009d35c4e02"
uuid = "cbdf2221-f076-402e-a563-3d30da359d67"
version = "0.6.7"

[[deps.Animations]]
deps = ["Colors"]
git-tree-sha1 = "e81c509d2c8e49592413bfb0bb3b08150056c79d"
uuid = "27a7e980-b3e6-11e9-2bcd-0b925532e340"
version = "0.4.1"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"

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

[[deps.Cairo]]
deps = ["Cairo_jll", "Colors", "Glib_jll", "Graphics", "Libdl", "Pango_jll"]
git-tree-sha1 = "d0b3f8b4ad16cb0a2988c6788646a5e6a17b6b1b"
uuid = "159f3aea-2a34-519c-b102-8c37f9878175"
version = "1.0.5"

[[deps.CairoMakie]]
deps = ["Base64", "Cairo", "Colors", "FFTW", "FileIO", "FreeType", "GeometryBasics", "LinearAlgebra", "Makie", "SHA"]
git-tree-sha1 = "cb87c60a56059760d53a4f0dd3b822b20a448a9d"
uuid = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"
version = "0.8.2"

[[deps.Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "4b859a208b2397a7a623a03449e4636bdb17bcf2"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.16.1+1"

[[deps.Chain]]
git-tree-sha1 = "339237319ef4712e6e5df7758d0bccddf5c237d9"
uuid = "8be319e6-bccf-4806-a6f7-6fae938471bc"
version = "0.4.10"

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "9950387274246d08af38f6eef8cb5480862a435f"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.14.0"

[[deps.ChangesOfVariables]]
deps = ["ChainRulesCore", "LinearAlgebra", "Test"]
git-tree-sha1 = "1e315e3f4b0b7ce40feded39c73049692126cf53"
uuid = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
version = "0.1.3"

[[deps.ColorBrewer]]
deps = ["Colors", "JSON", "Test"]
git-tree-sha1 = "61c5334f33d91e570e1d0c3eb5465835242582c4"
uuid = "a2cac450-b92f-5266-8821-25eda20663c8"
version = "0.4.0"

[[deps.ColorSchemes]]
deps = ["ColorTypes", "ColorVectorSpace", "Colors", "FixedPointNumbers", "Random"]
git-tree-sha1 = "7297381ccb5df764549818d9a7d57e45f1057d30"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.18.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "a985dc37e357a3b22b260a5def99f3530fb415d3"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.2"

[[deps.ColorVectorSpace]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "SpecialFunctions", "Statistics", "TensorCore"]
git-tree-sha1 = "d08c20eef1f2cbc6e60fd3612ac4340b89fea322"
uuid = "c3611d14-8923-5661-9e6a-0046d554d3a4"
version = "0.9.9"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "417b0ed7b8b838aa6ca0a87aadf1bb9eb111ce40"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.8"

[[deps.CommonSolve]]
git-tree-sha1 = "68a0743f578349ada8bc911a5cbd5a2ef6ed6d1f"
uuid = "38540f10-b2f7-11e9-35d8-d573e4eb0ff2"
version = "0.2.0"

[[deps.CommonSubexpressions]]
deps = ["MacroTools", "Test"]
git-tree-sha1 = "7b8a93dba8af7e3b42fecabf646260105ac373f7"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.0"

[[deps.Compat]]
deps = ["Base64", "Dates", "DelimitedFiles", "Distributed", "InteractiveUtils", "LibGit2", "Libdl", "LinearAlgebra", "Markdown", "Mmap", "Pkg", "Printf", "REPL", "Random", "SHA", "Serialization", "SharedArrays", "Sockets", "SparseArrays", "Statistics", "Test", "UUIDs", "Unicode"]
git-tree-sha1 = "b153278a25dd42c65abbf4e62344f9d22e59191b"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "3.43.0"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"

[[deps.ConstructionBase]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f74e9d5388b8620b4cee35d4c5a618dd4dc547f4"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.3.0"

[[deps.Contour]]
deps = ["StaticArrays"]
git-tree-sha1 = "9f02045d934dc030edad45944ea80dbd1f0ebea7"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.5.7"

[[deps.Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[deps.DataAPI]]
git-tree-sha1 = "fb5f5316dd3fd4c5e7c30a24d50643b73e37cd40"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.10.0"

[[deps.DataFrameMacros]]
deps = ["DataFrames"]
git-tree-sha1 = "cff70817ef73acb9882b6c9b163914e19fad84a9"
uuid = "75880514-38bc-4a95-a458-c2aea5a3a702"
version = "0.2.1"

[[deps.DataFrames]]
deps = ["Compat", "DataAPI", "Future", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrettyTables", "Printf", "REPL", "Reexport", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "daa21eb85147f72e41f6352a57fccea377e310a9"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.3.4"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "cc1a8e22627f33c789ab60b36a9132ac050bbf75"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.12"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"

[[deps.DensityInterface]]
deps = ["InverseFunctions", "Test"]
git-tree-sha1 = "80c3e8639e3353e5d2912fb3a1916b8455e2494b"
uuid = "b429d917-457f-4dbc-8f4c-0cc954292b1d"
version = "0.4.0"

[[deps.Dictionaries]]
deps = ["Indexing", "Random"]
git-tree-sha1 = "0340cee29e3456a7de968736ceeb705d591875a2"
uuid = "85a47980-9c8c-11e8-2b9f-f7ca1fa99fb4"
version = "0.3.20"

[[deps.DiffResults]]
deps = ["StaticArrays"]
git-tree-sha1 = "c18e98cba888c6c25d1c3b048e4b3380ca956805"
uuid = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
version = "1.0.3"

[[deps.DiffRules]]
deps = ["IrrationalConstants", "LogExpFunctions", "NaNMath", "Random", "SpecialFunctions"]
git-tree-sha1 = "28d605d9a0ac17118fe2c5e9ce0fbb76c3ceb120"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.11.0"

[[deps.Distances]]
deps = ["LinearAlgebra", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "3258d0659f812acde79e8a74b11f17ac06d0ca04"
uuid = "b4f34e82-e78d-54a5-968a-f98e89d6e8f7"
version = "0.10.7"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.Distributions]]
deps = ["ChainRulesCore", "DensityInterface", "FillArrays", "LinearAlgebra", "PDMats", "Printf", "QuadGK", "Random", "SparseArrays", "SpecialFunctions", "Statistics", "StatsBase", "StatsFuns", "Test"]
git-tree-sha1 = "d29d8faf1a0ca59167f04edd4d0eb971a6ae009c"
uuid = "31c24e10-a181-5473-b8eb-7969acd0382f"
version = "0.25.59"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "b19534d1895d702889b219c382a6e18010797f0b"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.8.6"

[[deps.Downloads]]
deps = ["ArgTools", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"

[[deps.EarCut_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "3f3a2501fa7236e9b911e0f7a588c657e822bb6d"
uuid = "5ae413db-bbd1-5e63-b57d-d24a61df00f5"
version = "2.2.3+0"

[[deps.Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "bad72f730e9e91c08d9427d5e8db95478a3c323d"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.4.8+0"

[[deps.FFMPEG]]
deps = ["FFMPEG_jll"]
git-tree-sha1 = "b57e3acbe22f8484b4b5ff66a7499717fe1a9cc8"
uuid = "c87230d0-a227-11e9-1b43-d7ebe4e7570a"
version = "0.4.1"

[[deps.FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "Pkg", "Zlib_jll", "libass_jll", "libfdk_aac_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "d8a578692e3077ac998b50c0217dfd67f21d1e5f"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "4.4.0+0"

[[deps.FFTW]]
deps = ["AbstractFFTs", "FFTW_jll", "LinearAlgebra", "MKL_jll", "Preferences", "Reexport"]
git-tree-sha1 = "505876577b5481e50d089c1c68899dfb6faebc62"
uuid = "7a1cc6ca-52ef-59f5-83cd-3a7055c09341"
version = "1.4.6"

[[deps.FFTW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c6033cc3892d0ef5bb9cd29b7f2f0331ea5184ea"
uuid = "f5851436-0d7a-5f13-b9de-f02708fd171a"
version = "3.3.10+0"

[[deps.FileIO]]
deps = ["Pkg", "Requires", "UUIDs"]
git-tree-sha1 = "9267e5f50b0e12fdfd5a2455534345c4cf2c7f7a"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.14.0"

[[deps.FillArrays]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "Statistics"]
git-tree-sha1 = "246621d23d1f43e3b9c368bf3b72b2331a27c286"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "0.13.2"

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

[[deps.ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions", "StaticArrays"]
git-tree-sha1 = "89cc49bf5819f0a10a7a3c38885e7c7ee048de57"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "0.10.29"

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
git-tree-sha1 = "b5c7fe9cea653443736d264b85466bad8c574f4a"
uuid = "663a7486-cb36-511b-a19d-713bb74d65c9"
version = "0.9.9"

[[deps.FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "aa31987c2ba8704e23c6c8ba8a4f769d5d7e4f91"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.10+0"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.GLM]]
deps = ["Distributions", "LinearAlgebra", "Printf", "Reexport", "SparseArrays", "SpecialFunctions", "Statistics", "StatsBase", "StatsFuns", "StatsModels"]
git-tree-sha1 = "92b8d38886445d6d06e5f13201e57d018c4ff880"
uuid = "38e38edf-8417-5370-95a0-9cbb8c7f171a"
version = "1.7.0"

[[deps.GeoInterface]]
deps = ["RecipesBase"]
git-tree-sha1 = "6b1a29c757f56e0ae01a35918a2c39260e2c4b98"
uuid = "cf35fbd7-0cd7-5166-be24-54bfbe79505f"
version = "0.5.7"

[[deps.GeometryBasics]]
deps = ["EarCut_jll", "IterTools", "LinearAlgebra", "StaticArrays", "StructArrays", "Tables"]
git-tree-sha1 = "83ea630384a13fc4f002b77690bc0afeb4255ac9"
uuid = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
version = "0.4.2"

[[deps.Gettext_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "9b02998aba7bf074d14de89f9d37ca24a1a0b046"
uuid = "78b55507-aeef-58d4-861c-77aaff3498b1"
version = "0.21.0+0"

[[deps.Glib_jll]]
deps = ["Artifacts", "Gettext_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "a32d672ac2c967f3deb8a81d828afc739c838a06"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.68.3+2"

[[deps.Graphics]]
deps = ["Colors", "LinearAlgebra", "NaNMath"]
git-tree-sha1 = "1c5a84319923bea76fa145d49e93aa4394c73fc2"
uuid = "a2bd30eb-e257-5431-a919-1863eab51364"
version = "1.1.1"

[[deps.Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "344bf40dcab1073aca04aa0df4fb092f920e4011"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.14+0"

[[deps.GridLayoutBase]]
deps = ["GeometryBasics", "InteractiveUtils", "Observables"]
git-tree-sha1 = "e7b3493c3e64d072a9f22c4b24bc51874a3edcdf"
uuid = "3955a311-db13-416c-9275-1d80ed98e5e9"
version = "0.7.5"

[[deps.Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[deps.HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg"]
git-tree-sha1 = "129acf094d168394e80ee1dc4bc06ec835e510a3"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "2.8.1+1"

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

[[deps.ImageCore]]
deps = ["AbstractFFTs", "ColorVectorSpace", "Colors", "FixedPointNumbers", "Graphics", "MappedArrays", "MosaicViews", "OffsetArrays", "PaddedViews", "Reexport"]
git-tree-sha1 = "9a5c62f231e5bba35695a20988fc7cd6de7eeb5a"
uuid = "a09fc81d-aa75-5fe9-8630-4744c3626534"
version = "0.9.3"

[[deps.ImageIO]]
deps = ["FileIO", "IndirectArrays", "JpegTurbo", "LazyModules", "Netpbm", "OpenEXR", "PNGFiles", "QOI", "Sixel", "TiffImages", "UUIDs"]
git-tree-sha1 = "d9a03ffc2f6650bd4c831b285637929d99a4efb5"
uuid = "82e4d734-157c-48bb-816b-45c225c6df19"
version = "0.6.5"

[[deps.Imath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "87f7662e03a649cffa2e05bf19c303e168732d3e"
uuid = "905a6f67-0a94-5f89-b386-d35d92009cd1"
version = "3.1.2+0"

[[deps.Indexing]]
git-tree-sha1 = "ce1566720fd6b19ff3411404d4b977acd4814f9f"
uuid = "313cdc1a-70c2-5d6a-ae34-0150d3930a38"
version = "1.1.1"

[[deps.IndirectArrays]]
git-tree-sha1 = "012e604e1c7458645cb8b436f8fba789a51b257f"
uuid = "9b13fd28-a010-5f03-acff-a1bbcff69959"
version = "1.0.0"

[[deps.Inflate]]
git-tree-sha1 = "f5fc07d4e706b84f72d54eedcc1c13d92fb0871c"
uuid = "d25df0c9-e2be-5dd7-82c8-3ad0b3e990b9"
version = "0.1.2"

[[deps.IntelOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "d979e54b71da82f3a65b62553da4fc3d18c9004c"
uuid = "1d5cc7b8-4909-519e-a0f8-d0f5ad9712d0"
version = "2018.0.3+2"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.Interpolations]]
deps = ["AxisAlgorithms", "ChainRulesCore", "LinearAlgebra", "OffsetArrays", "Random", "Ratios", "Requires", "SharedArrays", "SparseArrays", "StaticArrays", "WoodburyMatrices"]
git-tree-sha1 = "b7bc05649af456efc75d178846f47006c2c4c3c7"
uuid = "a98d9a8b-a2ab-59e6-89dd-64a1c18fca59"
version = "0.13.6"

[[deps.IntervalSets]]
deps = ["Dates", "Statistics"]
git-tree-sha1 = "ad841eddfb05f6d9be0bff1fa48dcae32f134a2d"
uuid = "8197267c-284f-5f27-9208-e0e47529a953"
version = "0.6.2"

[[deps.InverseFunctions]]
deps = ["Test"]
git-tree-sha1 = "336cc738f03e069ef2cac55a104eb823455dca75"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.4"

[[deps.InvertedIndices]]
git-tree-sha1 = "bee5f1ef5bf65df56bdd2e40447590b272a5471f"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.1.0"

[[deps.IrrationalConstants]]
git-tree-sha1 = "7fd44fd4ff43fc60815f8e764c0f352b83c49151"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.1.1"

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
git-tree-sha1 = "3c837543ddb02250ef42f4738347454f95079d4e"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.3"

[[deps.JpegTurbo]]
deps = ["CEnum", "FileIO", "ImageCore", "JpegTurbo_jll", "TOML"]
git-tree-sha1 = "a77b273f1ddec645d1b7c4fd5fb98c8f90ad10a5"
uuid = "b835a17e-a41a-41e7-81f0-2f016b05efe0"
version = "0.1.1"

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b53380851c6e6664204efb2e62cd24fa5c47e4ba"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "2.1.2+0"

[[deps.KernelDensity]]
deps = ["Distributions", "DocStringExtensions", "FFTW", "Interpolations", "StatsBase"]
git-tree-sha1 = "591e8dc09ad18386189610acafb970032c519707"
uuid = "5ab0869b-81aa-558d-bb23-cbf5423bbe9b"
version = "0.6.3"

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
git-tree-sha1 = "f4d24f461dacac28dcd1f63ebd88a8d9d0799389"
uuid = "8cdb02fc-e678-4876-92c5-9defec4f444e"
version = "0.3.0"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"

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
git-tree-sha1 = "42b62845d70a619f063a7da093d995ec8e15e778"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.16.1+1"

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
deps = ["Libdl", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.Loess]]
deps = ["Distances", "LinearAlgebra", "Statistics"]
git-tree-sha1 = "46efcea75c890e5d820e670516dc156689851722"
uuid = "4345ca2d-374a-55d4-8d30-97f9976e7612"
version = "0.5.4"

[[deps.LogExpFunctions]]
deps = ["ChainRulesCore", "ChangesOfVariables", "DocStringExtensions", "InverseFunctions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "09e4b894ce6a976c354a69041a04748180d43637"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.15"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.MKL_jll]]
deps = ["Artifacts", "IntelOpenMP_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "Pkg"]
git-tree-sha1 = "e595b205efd49508358f7dc670a940c790204629"
uuid = "856f044c-d86e-5d09-b602-aeab76dc8ba7"
version = "2022.0.0+0"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "3d3e902b31198a27340d0bf00d6ac452866021cf"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.9"

[[deps.Makie]]
deps = ["Animations", "Base64", "ColorBrewer", "ColorSchemes", "ColorTypes", "Colors", "Contour", "Distributions", "DocStringExtensions", "FFMPEG", "FileIO", "FixedPointNumbers", "Formatting", "FreeType", "FreeTypeAbstraction", "GeometryBasics", "GridLayoutBase", "ImageIO", "IntervalSets", "Isoband", "KernelDensity", "LaTeXStrings", "LinearAlgebra", "MakieCore", "Markdown", "Match", "MathTeXEngine", "Observables", "OffsetArrays", "Packing", "PlotUtils", "PolygonOps", "Printf", "Random", "RelocatableFolders", "Serialization", "Showoff", "SignedDistanceFields", "SparseArrays", "Statistics", "StatsBase", "StatsFuns", "StructArrays", "UnicodeFun"]
git-tree-sha1 = "048aec015ad88eb5c642d731e3e23f1b805ae8b3"
uuid = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"
version = "0.17.2"

[[deps.MakieCore]]
deps = ["Observables"]
git-tree-sha1 = "cd999cfcda9ae0dd564a968087005d25359344c9"
uuid = "20f20a25-4f0e-4fdf-b5d1-57303727442b"
version = "0.3.1"

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
deps = ["AbstractTrees", "Automa", "DataStructures", "FreeTypeAbstraction", "GeometryBasics", "LaTeXStrings", "REPL", "RelocatableFolders", "Test"]
git-tree-sha1 = "70e733037bbf02d691e78f95171a1fa08cdc6332"
uuid = "0a4f8689-d25c-4efe-a92b-7142dfc1aa53"
version = "0.2.1"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "bf210ce90b6c9eed32d25dbcae1ebc565df2687f"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.0.2"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MosaicViews]]
deps = ["MappedArrays", "OffsetArrays", "PaddedViews", "StackViews"]
git-tree-sha1 = "b34e3bc3ca7c94914418637cb10cc4d1d80d877d"
uuid = "e94cdb99-869f-56ef-bcf0-1ae2bcbe0389"
version = "0.3.3"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"

[[deps.NaNMath]]
git-tree-sha1 = "b086b7ea07f8e38cf122f5016af580881ac914fe"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "0.3.7"

[[deps.NamedTupleTools]]
git-tree-sha1 = "befc30261949849408ac945a1ebb9fa5ec5e1fd5"
uuid = "d9ec5142-1e00-5aa0-9d6a-321866360f50"
version = "0.14.0"

[[deps.Netpbm]]
deps = ["FileIO", "ImageCore"]
git-tree-sha1 = "18efc06f6ec36a8b801b23f076e3c6ac7c3bf153"
uuid = "f09324ee-3d7c-5217-9330-fc30815ba969"
version = "1.0.2"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"

[[deps.Observables]]
git-tree-sha1 = "dfd8d34871bc3ad08cd16026c1828e271d554db9"
uuid = "510215fc-4207-5dde-b226-833fc4488ee2"
version = "0.5.1"

[[deps.OffsetArrays]]
deps = ["Adapt"]
git-tree-sha1 = "52addd9e91df8a6a5781e5c7640787525fd48056"
uuid = "6fe1bfb0-de20-5000-8ca7-80f57d26f881"
version = "1.11.2"

[[deps.Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "887579a3eb005446d514ab7aeac5d1d027658b8f"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.5+1"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"

[[deps.OpenEXR]]
deps = ["Colors", "FileIO", "OpenEXR_jll"]
git-tree-sha1 = "327f53360fdb54df7ecd01e96ef1983536d1e633"
uuid = "52e1d378-f018-4a11-a4be-720524705ac7"
version = "0.3.2"

[[deps.OpenEXR_jll]]
deps = ["Artifacts", "Imath_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "923319661e9a22712f24596ce81c54fc0366f304"
uuid = "18a262bb-aa17-5467-a713-aee519bc75cb"
version = "3.1.1+0"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "ab05aa4cc89736e95915b01e7279e61b1bfe33b8"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "1.1.14+0"

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
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[deps.PCRE_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b2a7af664e098055a7529ad1a900ded962bca488"
uuid = "2f80f16e-611a-54ab-bc61-aa92de5b98fc"
version = "8.44.0+0"

[[deps.PDMats]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "027185efff6be268abbaf30cfd53ca9b59e3c857"
uuid = "90014a1f-27ba-587c-ab20-58faa44d9150"
version = "0.11.10"

[[deps.PNGFiles]]
deps = ["Base64", "CEnum", "ImageCore", "IndirectArrays", "OffsetArrays", "libpng_jll"]
git-tree-sha1 = "e925a64b8585aa9f4e3047b8d2cdc3f0e79fd4e4"
uuid = "f57f5aa1-a3ce-4bc8-8ab9-96f992907883"
version = "0.3.16"

[[deps.Packing]]
deps = ["GeometryBasics"]
git-tree-sha1 = "1155f6f937fa2b94104162f01fa400e192e4272f"
uuid = "19eb6ba3-879d-56ad-ad62-d5c202156566"
version = "0.4.2"

[[deps.PaddedViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "03a7a85b76381a3d04c7a1656039197e70eda03d"
uuid = "5432bcbf-9aad-5242-b902-cca2824c8663"
version = "0.5.11"

[[deps.Pango_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "FriBidi_jll", "Glib_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "3a121dfbba67c94a5bec9dde613c3d0cbcf3a12b"
uuid = "36c8627f-9965-5494-a995-c6b170f724f3"
version = "1.50.3+0"

[[deps.Parsers]]
deps = ["Dates"]
git-tree-sha1 = "1285416549ccfcdf0c50d4997a94331e88d68413"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.3.1"

[[deps.Pixman_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b4f5d02549a10e20780a24fce72bea96b6329e29"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.40.1+0"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"

[[deps.PkgVersion]]
deps = ["Pkg"]
git-tree-sha1 = "a7a7e1a88853564e551e4eba8650f8c38df79b37"
uuid = "eebad327-c553-4316-9ea0-9fa01ccd7688"
version = "0.1.1"

[[deps.PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "Printf", "Random", "Reexport", "Statistics"]
git-tree-sha1 = "bb16469fd5224100e422f0b027d26c5a25de1200"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.2.0"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "Markdown", "Random", "Reexport", "UUIDs"]
git-tree-sha1 = "670e559e5c8e191ded66fa9ea89c97f10376bb4c"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.38"

[[deps.PolygonOps]]
git-tree-sha1 = "77b3d3605fc1cd0b42d95eba87dfcd2bf67d5ff6"
uuid = "647866c9-e3ac-4575-94e7-e3d426903924"
version = "0.1.2"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "a6062fe4063cdafe78f4a0a81cfffb89721b30e7"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.2"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "47e5f437cc0e7ef2ce8406ce1e7e24d44915f88d"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.3.0"

[[deps.PrettyTables]]
deps = ["Crayons", "Formatting", "Markdown", "Reexport", "Tables"]
git-tree-sha1 = "dfb54c4e414caa595a1f2ed759b160f5a3ddcba5"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "1.3.1"

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

[[deps.QuadGK]]
deps = ["DataStructures", "LinearAlgebra"]
git-tree-sha1 = "78aadffb3efd2155af139781b8a8df1ef279ea39"
uuid = "1fd47b50-473d-5c70-9696-f719f8f3bcdc"
version = "2.4.2"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.Ratios]]
deps = ["Requires"]
git-tree-sha1 = "dc84268fe0e3335a62e315a3a7cf2afa7178a734"
uuid = "c84ed2f1-dad5-54f0-aa8e-dbefe2724439"
version = "0.4.3"

[[deps.RecipesBase]]
git-tree-sha1 = "6bf3f380ff52ce0832ddd3a2a7b9538ed1bcca7d"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.2.1"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.RelocatableFolders]]
deps = ["SHA", "Scratch"]
git-tree-sha1 = "cdbd3b1338c72ce29d9584fdbe9e9b70eeb5adca"
uuid = "05181044-ff0b-4ac5-8273-598c1e38db00"
version = "0.1.3"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[deps.Rmath]]
deps = ["Random", "Rmath_jll"]
git-tree-sha1 = "bf3188feca147ce108c76ad82c2792c57abe7b1f"
uuid = "79098fc4-a85e-5d69-aa6a-4863f24498fa"
version = "0.7.0"

[[deps.Rmath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "68db32dff12bb6127bac73c209881191bf0efbb7"
uuid = "f50d1b31-88e8-58de-be2c-1cc44531875f"
version = "0.3.0+0"

[[deps.Roots]]
deps = ["CommonSolve", "Printf", "Setfield"]
git-tree-sha1 = "30e3981751855e2340e9b524ab58c1ec85c36f33"
uuid = "f2b01f46-fcfa-551c-844a-d8ac1e96c665"
version = "2.0.1"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[deps.SIMD]]
git-tree-sha1 = "7dbc15af7ed5f751a82bf3ed37757adf76c32402"
uuid = "fdea26ae-647d-5447-a871-4b548cad5224"
version = "3.4.1"

[[deps.ScanByte]]
deps = ["Libdl", "SIMD"]
git-tree-sha1 = "9cc2955f2a254b18be655a4ee70bc4031b2b189e"
uuid = "7b38b023-a4d7-4c5e-8d43-3f3097f304eb"
version = "0.3.0"

[[deps.Scratch]]
deps = ["Dates"]
git-tree-sha1 = "0b4b7f1393cff97c33891da2a0bf69c6ed241fda"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.1.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Setfield]]
deps = ["ConstructionBase", "Future", "MacroTools", "Requires"]
git-tree-sha1 = "38d88503f695eb0301479bc9b0d4320b378bafe5"
uuid = "efcf1570-3423-57d1-acb7-fd33fddbac46"
version = "0.8.2"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[deps.ShiftedArrays]]
git-tree-sha1 = "22395afdcf37d6709a5a0766cc4a5ca52cb85ea0"
uuid = "1277b4bf-5013-50f5-be3d-901d8477a67a"
version = "1.0.0"

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

[[deps.Sixel]]
deps = ["Dates", "FileIO", "ImageCore", "IndirectArrays", "OffsetArrays", "REPL", "libsixel_jll"]
git-tree-sha1 = "8fb59825be681d451c246a795117f317ecbcaa28"
uuid = "45858cf5-a6b0-47a3-bbea-62219f50df47"
version = "0.1.2"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "b3363d7460f7d098ca0912c69b082f75625d7508"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.0.1"

[[deps.SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.SpecialFunctions]]
deps = ["ChainRulesCore", "IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "bc40f042cfcc56230f781d92db71f0e21496dffd"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.1.5"

[[deps.StackViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "46e589465204cd0c08b4bd97385e4fa79a0c770c"
uuid = "cae243ae-269e-4f55-b966-ac2d0dc13c15"
version = "0.1.1"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "Random", "Statistics"]
git-tree-sha1 = "cd56bf18ed715e8b09f06ef8c6b781e6cdc49911"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.4.4"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "c82aaa13b44ea00134f8c9c89819477bd3986ecd"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.3.0"

[[deps.StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "8977b17906b0a1cc74ab2e3a05faa16cf08a8291"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.33.16"

[[deps.StatsFuns]]
deps = ["ChainRulesCore", "InverseFunctions", "IrrationalConstants", "LogExpFunctions", "Reexport", "Rmath", "SpecialFunctions"]
git-tree-sha1 = "5950925ff997ed6fb3e985dcce8eb1ba42a0bbe7"
uuid = "4c63d2b9-4356-54db-8cca-17b64c39e42c"
version = "0.9.18"

[[deps.StatsModels]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "Printf", "REPL", "ShiftedArrays", "SparseArrays", "StatsBase", "StatsFuns", "Tables"]
git-tree-sha1 = "4352d5badd1bc8bf0a8c825e886fa1eda4f0f967"
uuid = "3eaba693-59b7-5ba5-a881-562e759f1c8d"
version = "0.6.30"

[[deps.StructArrays]]
deps = ["Adapt", "DataAPI", "StaticArrays", "Tables"]
git-tree-sha1 = "e75d82493681dfd884a357952bbd7ab0608e1dc3"
uuid = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
version = "0.6.7"

[[deps.SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "OrderedCollections", "TableTraits", "Test"]
git-tree-sha1 = "5ce79ce186cc678bbb5c5681ca3379d1ddae11a1"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.7.0"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"

[[deps.TensorCore]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1feb45f88d133a655e001435632f019a9a1bcdb6"
uuid = "62fd8b95-f654-4bbd-a8a5-9c27f68ccd50"
version = "0.1.1"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.TiffImages]]
deps = ["ColorTypes", "DataStructures", "DocStringExtensions", "FileIO", "FixedPointNumbers", "IndirectArrays", "Inflate", "OffsetArrays", "PkgVersion", "ProgressMeter", "UUIDs"]
git-tree-sha1 = "f90022b44b7bf97952756a6b6737d1a0024a3233"
uuid = "731e570b-9d59-4bfa-96dc-6df516fadf69"
version = "0.5.5"

[[deps.TranscodingStreams]]
deps = ["Random", "Test"]
git-tree-sha1 = "216b95ea110b5972db65aa90f88d8d89dcb8851c"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.9.6"

[[deps.Tricks]]
git-tree-sha1 = "6bac775f2d42a611cdfcd1fb217ee719630c4175"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.6"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

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
git-tree-sha1 = "1acf5bdf07aa0907e0a37d3718bb88d4b687b74a"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.9.12+0"

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

[[deps.isoband_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "51b5eeb3f98367157a7a12a1fb0aa5328946c03c"
uuid = "9a68df92-36a6-505f-a73e-abb412b6bfb4"
version = "0.2.3+0"

[[deps.libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "5982a94fcba20f02f42ace44b9894ee2b140fe47"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.15.1+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl", "OpenBLAS_jll"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"

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
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "78736dab31ae7a53540a6b752efc61f77b304c5b"
uuid = "075b6546-f08a-558a-be8f-8157d0f608a5"
version = "1.8.6+1"

[[deps.libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll", "Pkg"]
git-tree-sha1 = "b910cb81ef3fe6e78bf6acee440bda86fd6ae00c"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.7+1"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"

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
# ╟─f5450eab-0f9f-4b7f-9b80-992d3c553ba9
# ╟─f0765abe-d6d3-11ec-0c46-e909705296dd
# ╟─e96bdfab-4bd4-4c79-9478-413efe1014d3
# ╠═3a54e974-1f95-4107-8959-642a8d2ea155
# ╠═b529ed26-50c8-452d-b4ae-1939ef8c58d2
# ╠═a739eec7-b301-4536-9473-682245275672
# ╠═11f4d233-ddf0-4e03-84a5-11623ba14d01
# ╠═365af2cb-c595-4435-9c62-4d28d33aa1ec
# ╠═d312e74b-b9ad-479c-a3c1-7c7d418d183c
# ╟─ba1ba3f4-1b4a-4158-8b50-2398502e8998
# ╠═1f00565d-3946-4cb5-95f9-672571b8c170
# ╟─b5c3c809-4797-434e-a66b-2cefe1f1be36
# ╠═ff0ddbc0-9d7b-492e-add5-031bc07d0d4a
# ╠═7fcbbab9-6205-4d6e-962a-e24b02737fef
# ╠═de5d783c-6cd7-4064-8f15-2b60eda61bdb
# ╠═67ee0656-a813-4b50-a57b-211b3ba3e2be
# ╟─0bd0d100-c5eb-4fc7-a2a2-0a93e83e5d53
# ╠═61e6875b-b9d3-4ffa-8c44-53642bdb03f1
# ╠═713d34c8-4a45-44dd-9ac7-ef94d6cb2b15
# ╠═65dd9858-e847-47ed-a700-51bdb53bbacf
# ╠═af5abc37-84c6-4aac-a5e7-aea1ab3e5848
# ╟─999cc543-b87a-4b3c-b39f-4e0c31ff2898
# ╠═859d0b3a-bcce-4f61-a1f1-d7b45444209a
# ╟─f9c98149-71e0-423d-b7b0-caeea8168479
# ╠═fb4bc15c-9ad7-4546-9a8a-06c76a1c4e27
# ╟─7a6651d9-7c37-4773-ba02-8db0513e75e7
# ╠═51526b20-2654-4dec-908f-17b54f738575
# ╠═0d668039-d550-4f80-a816-1ff788f2ab32
# ╠═2329e8e6-1dd6-4507-9d5f-77c3d5bb8a52
# ╠═a94938a4-2119-4ada-a143-ff15683a796b
# ╠═3b8d01da-ea17-46ec-b958-b580b0b6b002
# ╠═2599fc83-6528-454f-94f4-85d56689573b
# ╠═a34f03d4-e987-4cb1-9a83-106ac70b3db1
# ╠═e7956e57-bbaf-4d69-abbd-6cac19df0791
# ╟─b2b2d669-7be8-4ed5-be73-6b9bff387c9a
# ╠═a727150c-eb49-4cc1-9425-81bab85f9ba5
# ╟─c4478a12-e5b3-4720-a0df-751a3b7b4d22
# ╟─e7e22e88-078d-48c6-aa43-375429ae8e69
# ╟─e1e9fded-7a71-4c8f-9dc3-03644597a654
# ╟─154a532c-0864-413e-9593-cdbf624b90fb
# ╠═6db3164e-6e62-4e04-aa3b-4dfab1bb0065
# ╠═fb7d5518-1ae6-4a16-b35a-954306ed94dc
# ╠═42aa25ec-16fc-4bdf-9341-dc1296d6826a
# ╠═1efe99f4-a6d6-4994-a9a5-ba50e4247e1f
# ╠═0da88cb6-44ed-4129-af28-26fd67643874
# ╠═53585d7f-d466-41df-9213-b07265c9571a
# ╠═ab8778fc-065e-4ba9-aeb3-dfe86e0f6ca5
# ╠═13f0b6e2-cb6a-48f2-b0dc-fb942a5f948a
# ╠═a2d4bf8e-cad5-4d78-bbbf-edd34e470ccb
# ╟─37560b71-5888-41b5-b0b7-2e477e64d80e
# ╠═3df41f6a-0c86-4306-8a5d-eab208c717c2
# ╠═13a7d8d2-9d3e-452e-99ea-605e0e91b589
# ╠═f82b306c-338c-4a4b-88d7-86fa9aa846a1
# ╠═2ea0f7cc-73c5-4f78-b490-878ce3e5f341
# ╠═d3c43f6c-7bfd-4b3c-b0b9-9adac24a31ae
# ╠═4614d327-09be-494c-8284-c90dd254cdb3
# ╠═787d3365-a764-4f07-9aed-78d601b70aaf
# ╠═a8e926c2-4187-4ec8-85f6-14c8179a3eb8
# ╠═eddb517b-685f-494c-979e-4d6773593268
# ╠═f0233537-0fd8-4ae6-bd22-bb4c9bae5813
# ╟─2cdd1dd3-f2ef-4532-a91a-6df387954c5e
# ╠═d3974a05-fd05-467e-a575-95cea4afa6cd
# ╠═fbd39ec2-7cd5-4e2e-8547-4a55842b395b
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002