### A Pluto.jl notebook ###
# v0.19.25

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

# ╔═╡ d24ef390-0824-4c03-b1a9-236b8a982a92
using Roots: find_zero, Brent

# ╔═╡ 7931c043-9379-44f9-bab2-6d42153aa3d3
using PlutoUI: TableOfContents, Slider

# ╔═╡ 9df5eb89-7ff6-4749-b3c1-4199e22d1d07
using AlgebraOfGraphics, CairoMakie

# ╔═╡ b9db33eb-bb0c-4510-8c7e-2aad8b30de5e
using AlgebraOfGraphics: draw

# ╔═╡ dfa54f23-8141-4270-8344-08975d90322d
using DataFrameMacros

# ╔═╡ 719dce77-eb0f-4ebb-b6c5-eb8911e842a4
using Chain: @chain

# ╔═╡ d730d979-21ae-4c00-820f-b481b8b5cd4a
using DataFrames

# ╔═╡ 41f783a0-5cfa-4c83-a66c-37243170d01b
using LinearAlgebra

# ╔═╡ a11be816-ceef-4986-b313-6d429c8231be
using Statistics: mean

# ╔═╡ 7575ffb0-ee67-48e8-8682-55385d40b50e
using StatsBase: weights

# ╔═╡ 6b8b0739-af1a-4ee9-89f1-291afdc47980
using QuantEcon

# ╔═╡ 1b5abb2b-5dc7-433c-9c83-6cfd06c8eadf
md"""
`welfare-huggett-solution.jl` | **Version 1.2** | *last updated: June 2, 2023* | *created by [Daniel Schmidt](https://github.com/danieljschmidt)*
"""

# ╔═╡ a0825503-c132-4c12-93e2-60537d0f6085
md"""
# Welfare analysis
"""

# ╔═╡ cc3fe476-950f-4351-8d12-4f5a8f359317
md"""
This notebook provides a brief introduction to welfare analysis in models with household heterogeneity. There are two approaches:

1. How much are newborn agents in the stationary equilibrium with the reform better off compared to the stationary equilibrium without the reform?
2. How much are agents (of any age) who are alive at the time of the reform better off compared to the stationary equilibrium without the reform?

The second approach is more difficult because we need to take transitional dynamics after the reform into account. Therefore, this notebook covers only the first approach. We consider the introduction of an income tax in a perpetual youth - version of the Huggett model.
"""

# ╔═╡ 77cfd0d8-5af0-417b-8161-f1c264ce20b4
md"""
## Partial equilibrium
"""

# ╔═╡ b8840490-5a17-44e2-8703-f9b845597111
md"""
```math
\begin{align}
&\max_{\{c_t\}} \operatorname{E}_0\Bigl(\sum_{t=0}^\infty \beta^t (1-m)^t u(c_t) \Bigr) \\
&\begin{aligned}
	\text{subject to } 
		&c_t + k_t = k_{t-1}(1 + r) + y_t - T(y_t) \\
		&y_t \sim \text{some Markov Chain} \\
		&y_0, k_{-1} \text{ given}
\end{aligned}
\end{align}
```

There are two changes compared to the households' problem in the ```aiyagari.jl``` notebook:
- the income tax $T(y_t)$ which depends on current income
- the death probability $m$

Since the death probability in our model does not depend on age, the optimization problem of a 100-year-old household looks the same as the one of a newborn household. This is why a model with such a demographic structure is also referred to as "perpetual youth model".
"""

# ╔═╡ 19978cfa-2798-475e-b057-083690b83b42
md"""
### Parameterization
"""

# ╔═╡ 28f1dbcd-1cbc-4c6c-9efe-9df2c0f5f881
function Household(; σ = 1.0, β = 0.96,	m = 1/50,
                      u = σ == 1 ? log : x -> x^(1 - σ) / (1 - σ))
	(; β, m, u)
end

# ╔═╡ 3965321e-baaa-484d-a722-854201085e58
function uniform_distribution(n_k, n_z; i_max = n_k)
	π₀ = zeros(n_k * n_z)
	π₀[1:i_max]         .= 0.5/i_max
	π₀[n_k+1:n_k+i_max] .= 0.5/i_max
	@assert sum(π₀) ≈ 1.
	π₀'
end

# ╔═╡ 39b3e67f-ea18-4068-b63f-564f77ff237b
begin
	
	# death probability
	m = 1/50

	# preference parameters
	σ = 2.
	β = 0.94

	hh = Household(; β, σ, m)

	# interest rate
	r = 0.03
	prices = (q = 1/(1+r), w = 1.0, Δr = 0.)

	# income process
	n_y = 2
	y_1 = 0.75
	y_2 = 1.25
	ρ = 0.75
	y_trans = [ρ 1-ρ; 1-ρ ρ]
	y_chain = MarkovChain(y_trans, [y_1, y_2])

	# asset grid
	n_k = 100
	k_min = -0.5
	k_max = 4.5
	k_vals = range(k_min, k_max, length = n_k)

	# distribution of newborn households over the state space
	π₀ = uniform_distribution(n_k, n_y)
	
end;

# ╔═╡ 520250f5-0877-4c36-a6f5-0b74a2916f37
md"""
- We start with a partial equilibrium version of the model. The interest rate $r=$ $(round(r,digits=4)) is exogenous.
- The death probability is $(m) which implies an expected lifetime (as an adult) of $(1/m) years.
- The income process has only two states $y^1 < y^2$ and the transition matrix is symmetric. In this case, the probability $\rho$ to stay in the current income state completely determines the transition matrix.
- We assume that there is no income tax in the initial stationary equilibrium, i.e. $T(y) = 0$.
- With a probability of 50% a newborn household is born into the high-income state. The distribution of assets of newborn households is uniform over the asset grid.
"""

# ╔═╡ a7e67216-2bca-45d7-859b-b9e0328c4875
md"""
### Solving the households' problem
"""

# ╔═╡ a56f8765-cae6-40f4-aebf-900673ed9710
md"""
To solve the households' problem, we treat the perpetual youth agents as infinitely-lived agents with a modified discount factor $\tilde{\beta} = \beta(1-m)$.
"""

# ╔═╡ b40c8fdb-6d4b-4880-8e7c-523bdb95a847
md"""
### Stationary distribution
"""

# ╔═╡ 9c1e3401-5646-4b6e-a703-0b0d877bcd6b
md"""
The ```QuantEcon``` framework gives us a matrix $Q^*$ with transition probabilities from $(y, k)$ to $(y', k')$ for households that do not die in between periods. To compute the correct stationary distribution, we also need to take the death probability into account (see lecture 1):

$$\pi_\infty = (1-m) \cdot Q^* \cdot \pi_\infty + m \cdot \pi_0$$

$$\implies \pi_\infty = (I - (1-m) \cdot Q^*)^{-1} (m \cdot \pi_0)$$

where $\pi_0$ is the distribution of newborn agents over the state space.
"""

# ╔═╡ 4eff64c0-16f1-48b0-87ec-d9f49599d0b0
function stationary_distribution(Q::AbstractMatrix, m, π₀)
	π = m * (π₀ / (I - (1-m) * Q))
	π'
end

# ╔═╡ fc6e8503-08bd-4df3-987e-2d926504ba34
md"""
### Tax reform
"""

# ╔═╡ ef3ab9ee-ae95-4482-b17f-48c50c0fdcb9
md"""
Now, let us consider the introduction of a income tax $\tau(y)$ that redistributes an amount $\tau$ from households in the high-income state to households in the low-income state:

$$T(y^1) = - \tau$$
$$T(y^2) = \tau$$
"""

# ╔═╡ 03439979-79cd-492d-a04e-bee96d67a9cb
τ = 0.05

# ╔═╡ 31a30781-59c9-4a56-be71-dd12626ae9ec
md"""
Since there are as many households in the high-income state as in the low-income state, such a income tax would generate no revenues for the government.

From the perspective of the households, the introduction of such an income tax is equivalent to modifying the income process:

$$y^1_\tau = y^1 - T(y^1) = y^1 + \tau$$
$$y^2_\tau = y^2 - T(y^2) = y^2 - \tau$$
"""

# ╔═╡ d7b1e1a4-3153-4fb7-9908-55ce65d7fa2f
y_chain_τ   = MarkovChain(y_trans, [y_1+τ, y_2-τ])

# ╔═╡ a2030a1e-6da9-4f5f-a367-03cd98530d7c
md"""
Below, we compute the solution to the households' problem in the stationary equilibrium with the reform. (Since we consider the partial equilibrium case here, we keep the interest rate fixed.)
"""

# ╔═╡ c5cb959f-8c66-4084-9a53-4cf422cdf762
md"""
### Conditional welfare changes $\Delta(k, y)$
"""

# ╔═╡ b8ab52fc-07f2-4512-b477-df1e294d91a7
	md"""
We can see whether an agent who is born into state $(k, y)$ is better off or not by comparing 
- the value function in the original stationary equilibrium $V(k, y)$ with 

- the value function in the stationary equilibrium with the redistributive income tax $V_\tau(k, y)$.
"""

# ╔═╡ 9c1efccf-1235-472d-b395-10dc5494d114
md"""
-----------------
"""

# ╔═╡ 69004cfb-29ea-4757-8eb6-3e905da0b2cb
md"""
### Exercise 1: Economic intuition

The plot of the value functions above shows that agents who are born into the low income state are better off, as expected. However, the plot also shows that agents who are born into the high income state are better off.

👉 How is this possible?
"""

# ╔═╡ 0abcb92d-838a-4fa6-a1bb-5bc6d7499e85
md"""
The introduction of the redistributive income tax has two effects on the agent in the high income state:
1. Current net income and expected future net incomes decrease
2. Income risk in the future decreases
The first effect decreases the value function in the high income state, the second effect increases it (the agents dislike income risk). It depends on the parameter values which of the two effects is more important quantitatively. 
"""

# ╔═╡ 02d23829-b7f8-415d-aca1-b71992b72bdb
md"""
-----------------
"""

# ╔═╡ 59f22787-ab1e-4096-9e43-39f33ba42713
md"""
In order to quantify the welfare changes due to the income tax, we need to transform the differences in the value functions into units of the consumption good. First, we need to make a few definitions:

The value function in the stationary equilibrium without the reform is:

```math
\begin{align}
V(k_{-1}, y_0)&= \operatorname{E}_0\Bigl(\sum_{t=0}^\infty \beta^t (1-m)^t u(c(k_{t-1}, y_t)) \Bigr) \\
&\begin{aligned}
	\text{subject to } 
		&k_t  = k_{t-1}(1 + r) + y_t - c(k_{t-1}, y_t) \\
\end{aligned}
\end{align}
```

The value function in the stationary equilibrium with the reform is:

```math
\begin{align}
V_\tau(k_{-1}, y_0)&= \operatorname{E}_0\Bigl(\sum_{t=0}^\infty \beta^t (1-m)^t u(c_\tau(k_{t-1}, y_t)) \Bigr) \\
&\begin{aligned}
	\text{subject to } 
		&k_t  = k_{t-1}(1 + r) + y_t - T(y_t) - c_\tau(k_{t-1}, y_t) \\
\end{aligned}
\end{align}
```

where $c(k,y)$ is optimal consumption in the stationary equilibrium without the reform and $c_\tau(k, y)$ is the optimal consumption in the stationary equilibrium with the reform.

If consumption in the stationary equilibrium without the reform is increased by a fraction $\Delta$ in each state of the world, the sum of expected utilities becomes:

```math
\begin{align}
W(k_{-1}, y_0; \Delta)&= \operatorname{E}_0\Bigl(\sum_{t=0}^\infty \beta^t (1-m)^t u((1+\Delta)c(k_{t-1}, y_t)) \Bigr) \\
&\begin{aligned}
	\text{subject to } 
		&k_t  = k_{t-1}(1 + r) + y_t - c(k_{t-1}, y_t) \\
\end{aligned}
\end{align}
```

Note that we do not allow the agent to reoptimize with respect to the relative consumption increase $\Delta$ in the definition of $W(k, y; \Delta)$.

We can finally define the conditional welfare change for an agent born into state $(k,y)$ as the relative increase in consumption $\Delta(k,y)$ in the stationary equilibrium without the reform that makes the agent as well off as in the stationary equilibrium with the reform:

$$V_\tau(k,y) = W(k,y; \Delta(k,y))$$

"""

# ╔═╡ 66e4ff89-288c-4963-bb7d-8cfde20e42a0
md"""
----------
"""

# ╔═╡ 8c185d30-7de4-4273-a739-d2af1d46a3a8
md"""
### Exercise 2: Formula for CRRA utility

Usually the equation above needs to be solved numerically for $\Delta(k,y)$. However, with the utility function chosen in this notebook

$$u(c) = \frac{c^{1-\sigma}}{1-\sigma}$$

a simpler approach is possible.

👉 Derive a simple analytical formula for $\Delta(k,y)$ in terms of $V(k,y)$ and $V_\tau(k,y)$.

Hint: Try to express $W(k,y; \Delta)$ in terms of $V(k,y)$.
"""

# ╔═╡ a453a9dc-0345-4630-8a75-e26a0de10e66
md"""
Step 1:
```math
\begin{align}
u((1+\Delta)c) &= \frac{((1+\Delta)c)^{1-\sigma}}{1-\sigma} = (1+\Delta)^{1-\sigma} u(c)\\
\implies W(k,y;\Delta) &= \operatorname{E}_0\Bigl(\sum_{t=0}^\infty \beta^t (1-m)^t u((1+\Delta)c(k_{t-1}, y_t)) \Bigr) = (1+\Delta)^{1-\sigma} V(k, y)
\end{align}
```

Step 2:
```math
\begin{align}
V_\tau(k,y) &= W(k,y; \Delta)\\
\implies V_\tau(k,y) &= (1+\Delta)^{1-\sigma} V(k, y)\\
\implies \Delta &= \Bigl(\frac{V_\tau(k,y)}{V(k,y)}\Bigr)^{1/(1-\sigma)} - 1
\end{align}
```
"""

# ╔═╡ 3e5158e4-146e-4b68-a20a-9b315de51de3
md"""
👉 Write a Julia function ```Δ_CRRA``` that computes $\Delta$ for given values ```v_τ``` and ```v``` and a given risk aversion coefficient $\sigma$.
"""

# ╔═╡ f6faaf5b-e7ca-4081-8faf-f2cf189e8ab4
function Δ_CRRA(v_τ, v, σ)
	(v_τ / v) ^ (1/(1-σ)) - 1
end

# ╔═╡ 849308de-b2e9-4f97-a948-60341863e7f8
md"""
----------
"""

# ╔═╡ c7ca1ce9-8621-4ae1-ab4a-c924d90745d6
md"""
After finishing the exercise above, activate the cells below, and Julia will generate a plot of $\Delta(k,y)$.
"""

# ╔═╡ 4f1fd4c1-1369-4e33-8e49-7ec51d33051c
md"""
### Unconditional welfare change $\Delta$
"""

# ╔═╡ f91d1b23-5670-4de4-81f4-cd72c0deb085
md"""
Since all agents benefit from the reform considered above, we can be sure that the aggregate welfare change is also possible (regardless of how the individual utilities are aggregated).

But if some agents lose and others gain, simply computing conditional welfare changes is not sufficient to understand whether a certain tax policy is desirable.

For this purpose, we need to define a welfare function to aggregate the maximized utility among the newborn agents. We choose a utilitarian welfare function here:

$$V = \sum_{y\in\{y^1, y^2\}}\int_{k_\min}^\infty V(k,y) \pi_0(k,y) dk$$

Since we only consider newborn agents, we integrate with respect to the distribution $\pi_0$ and not with respect to the stationary distribution $\pi$.

The unconditional welfare change is then defined as the relative change in consumption $\Delta$ such that

$$\underbrace{\sum_{y\in\{y^1, y^2\}}\int_{k_\min}^\infty V_\tau(k,y) \pi_0(k,y) dk}_{=V_\tau} = \sum_{y\in\{y^1, y^2\}}\int_{k_\min}^\infty W(k,y; \Delta) \pi_0(k,y) dk$$
"""

# ╔═╡ db24325c-49d8-45f7-805c-65b58a85889a
md"""
In the special case of a CRRA utility function, the right-hand side simplifies to $(1+\Delta)^{1-\sigma}V$ and the unconditional welfare change is simply

$$\Delta = \Bigl(\frac{V_\tau}{V}\Bigr)^{1/(1-\sigma)} - 1$$
"""

# ╔═╡ 30682ba5-d144-4c4d-bd7f-da16d6bf68fd
md"""
The unconditional welfare benefit corresponds to a relative change in consumption of approximately 1%.
"""

# ╔═╡ 7af904d0-fc43-4986-a17a-2bc12d7913f6
md"""
It is even possible to compute welfare changes conditional on the income state $y$ but to integrate over the asset space:
"""

# ╔═╡ fcafcc6c-cc23-4ae1-8ff3-5bebd4e1ec13
md"""
---
"""

# ╔═╡ 1f192db7-0c79-42e9-b433-8d6f78bafee4
md"""
### Exercise 3: Comparative statics
"""

# ╔═╡ 8382365c-99a0-4c29-9917-3a1f5f0b5af4
md"""
Explore the conditional and the unconditional welfare changes using the sliders below. 

 $\Delta_0(k,y)$ refers to the welfare change under the baseline parameterization, and $\Delta(k,y)$ to the welfare change with the current position of the sliders.

👉 Can you find a parameterization such that agents in the high income state have a welfare loss? 
"""

# ╔═╡ bb48a69b-72bd-4b50-848a-1b438555164c
md"""
Agents in the high income state are worse off with the reform if the persistence parameter $\rho$ is sufficiently high (e.g. $\rho = 0.95$).
"""

# ╔═╡ 143aa896-fc61-450c-843d-88546e129abd
md"""
👉 Try to understand how changes in the parameters $\rho$ and $\sigma$ affect the welfare of the agents.
"""

# ╔═╡ 24e51342-df5d-448a-a76f-18375af543aa
md"""

 $\sigma \uparrow$

Agents in both income states:
- decrease of income risk is valued more by agents $\implies$ $\Delta(k,y)$ increases

 $\rho \uparrow$

Agents in low income state: 
- stronger positive effect on expected future incomes $\implies$ $\Delta(k,y=y^1)$ increases
Agents in high income state: 
- stronger negative effect on expected future incomes $\implies$ $\Delta(k,y=y^2)$ decreases

"""

# ╔═╡ 8252bc6d-7303-4c67-9daa-f536b173cfde
md"""
Persistence parameter $\rho$

$(@bind ρ_sl Slider(0.5:0.025:0.975, show_value = true, default = ρ))
"""

# ╔═╡ 28762c0a-76a3-44e8-8a48-dbc57dec4282
md"""
Risk aversion $\sigma$

$(@bind σ_sl Slider(1.25:0.25:3., show_value = true, default = σ))
"""

# ╔═╡ 6e641df2-8b5b-49d8-88fc-36fa4b44b6e5
md"""
---
"""

# ╔═╡ d83a55d6-2901-4539-9ebb-3b16ecb02a3d
md"""
## General equilibrium
"""

# ╔═╡ d748feac-e583-4028-b3aa-6d1ac692255b
md"""
Net asset supply is zero. The market clearing condition is:

$$\sum_{y\in\{y^1, y^2\}} \int_{k_\min}^\infty k \pi(k,y) dk = 0$$
"""

# ╔═╡ 5be45b08-726c-453b-b025-cf7f69f941ff
md"""
### Finding the equilibrium interest rate
"""

# ╔═╡ afe1dfa0-7b61-4a7b-a98c-e3ffce756591
initial_bracket = (0.0, 0.1)

# ╔═╡ 24961de2-8e9a-4fd5-b6bf-8c0ccbd9d9a1
md"""
--------
"""

# ╔═╡ 28599228-417f-404f-bf3d-15ae388aff3b
md"""
### Exercise 4: Economic intuition

👉 Why does the introduction of the redistributive income tax cause the interest rate in the stationary equilibrium to increase?
"""

# ╔═╡ 54887913-20f4-48c8-ae1a-8ae623ee44ee
md"""
The higher the difference in net incomes across the two income states, the higher asset demand in the model (both because of consumption smoothing and for precautionary reasons). Since the tax reform decreases the difference in net incomes, asset demand decreases and hence the interest rate has to increase.
"""

# ╔═╡ 281fca35-1d20-417a-8928-ddd81c32b305
md"""
--------
"""

# ╔═╡ d379a396-0735-4fc9-aa6c-190d69a00fb0
md"""
### Welfare analysis in GE
"""

# ╔═╡ 23695e8e-9e3a-4519-bcef-82094833dcd9
md"""
---
"""

# ╔═╡ 8cde58db-b774-4348-9ae1-25791a20a997
md"""
### Exercise 5: Economic intuition

👉 Explain why the conditional welfare changes are different in general equilibrium (GE) compared to the partial equilibrium (PE) case.
"""

# ╔═╡ 18b470fa-d747-4ac2-a5aa-01f7671499a8
md"""
Higher interest rates are bad for households that borrow, and good for households that lend. This is why the welfare gain for agents with little or no assets is lower in GE than in PE, while the welfare gain for wealthy assets is higher in GE than in PE.
"""

# ╔═╡ cbcf8f08-0330-4458-ba7d-eb35f0d6b120
md"""
---
"""

# ╔═╡ a7130a4b-fb28-420e-b3a2-b0fd57532ce8
md"""
# Appendix
## Functions from ```aiyagari.jl```
"""

# ╔═╡ 9c4eeb4c-bc2c-428e-9c5b-d1424e7d42fe
function statespace(;
			k_vals = range(1e-10, 20.0, length = 200),
			z_chain
		)
	states = 
		[(; k, z) for k ∈ k_vals, z ∈ z_chain.state_values] |> vec
	states_indices = 
		[(; k_i, z_i) for k_i ∈ 1:length(k_vals), z_i ∈ 1:length(z_chain.state_values)] |> vec
    policies = 
	    [(; k_next) for k_next ∈ k_vals] |> vec
	policies_indices = 
	    [(; k_next_i) for k_next_i ∈ 1:length(k_vals)] |> vec

	(; states, states_indices, policies, policies_indices, z_chain)
end

# ╔═╡ ce25751c-949a-4ad3-a572-679f403ccb98
function setup_Q!(Q, states_indices, policies_indices, z_chain)
    for (i_next_state, next) ∈ enumerate(states_indices)
        for (i_policy, (; k_next_i)) ∈ enumerate(policies_indices)
            for (i_state, (; z_i)) ∈ enumerate(states_indices)
                if next.k_i == k_next_i
                    Q[i_state, i_policy, i_next_state] = z_chain.p[z_i, next.z_i]
                end
            end
        end
    end
    return Q
end

# ╔═╡ 96b42aa6-8700-42d1-a4a1-949595549e4b
function setup_Q(states_indices, policies_indices, z_chain)
	Q = zeros(length(states_indices), length(policies_indices), length(states_indices))
	setup_Q!(Q, states_indices, policies_indices, z_chain)
	Q
end

# ╔═╡ d60367db-cf92-4c0a-aea4-eddb6552e2c8
function consumption((; z, k), (; k_next), (; q, w, Δr))
	if k_next < 0 && Δr > 0
		r = (1/q - 1) + (k_next < 0) * Δr
		q = 1/(1+r)
	end
	c = w * z + k - q * k_next
end

# ╔═╡ e3930baf-0560-4994-a637-7cb1923ce33c
function reward(state, policy, prices, u)
	c = consumption(state, policy, prices)
    if c > 0
		u(c)
	else
		-100_000 + 100 * c
	end
end

# ╔═╡ 13fbec57-6ebe-456e-bfc9-ee98ce85d09e
function setup_R!(R, states, policies, prices, u)
    for (k_i, policy) ∈ enumerate(policies)
        for (s_i, state) ∈ enumerate(states)
            R[s_i, k_i] = reward(state, policy, prices, u)
        end
    end
    return R
end

# ╔═╡ 32f46a06-0832-479e-a00b-346cab1f8f5f
function setup_R(states, policies, prices, u)
	R = zeros(length(states), length(policies))
	setup_R!(R, states, policies, prices, u)
end

# ╔═╡ 23e83dbd-ad68-4b86-80a3-34c65ca420d1
function setup_DDP(household, statespace, prices)
	(; β, u, m) = household
	(; states, policies, states_indices, policies_indices) = statespace
    
	R = setup_R(states, policies, prices, u)
	Q = setup_Q(states_indices, policies_indices, statespace.z_chain)

	DiscreteDP(R, Q, β*(1-m))
end

# ╔═╡ 5954bfdf-d8c3-48b9-9871-5e2ed6d77e1d
md"""
The function below is similar to the ```solve_details``` functions from the ```aiygari.jl``` notebook:
"""

# ╔═╡ c1ec949c-c6ba-43e5-a6b3-3e40f499a6ca
function results_to_df(results, states, policies, prices)

	df = [DataFrame(states) DataFrame(policies[results.sigma])]
	df.state = states
	df.value = results.v
	df.policy = policies[results.sigma]

	@chain df begin
		@transform(:consumption = consumption(:state, :policy, prices))
		@transform(:saving = :k_next - :k)
		select!(Not([:state, :policy]))
	end

	df
end	

# ╔═╡ c8192e26-5215-4bbb-b1a7-da9df02b7e62
function solve_PE(hh, ss, prices, π₀)
	
	ddp       = setup_DDP(hh, ss, prices)
	results   = QuantEcon.solve(ddp, PFI)
	df        = results_to_df(results, ss.states, ss.policies, prices)
	df.π₀     = π₀'
	_, Q_star = RQ_sigma(ddp, results.sigma)
	df.π      = stationary_distribution(Q_star, hh.m, π₀)
	df.income = ifelse.(df.z .== ss.z_chain.state_values[1], "low", "high")
	
	df
end

# ╔═╡ b16d6fab-6bd1-4a39-a654-0fcb4ad868ee
begin
	ss = statespace(; k_vals, z_chain=y_chain)
	df = solve_PE(hh, ss, prices, π₀)
end;

# ╔═╡ 4bdd9050-87f7-4551-88d5-5c2cca569bb8
let
	figure = (; resolution = (600, 300))

	@chain df begin
		data(_) * mapping(:k, :π, color = :income) * visual(Lines)
		draw(; figure)
	end
end

# ╔═╡ 548005d3-e608-4e9f-af60-909394c8e67c
begin
	ss_τ = statespace(; k_vals, z_chain=y_chain_τ)
	df_τ = solve_PE(hh, ss_τ, prices, π₀)
end;

# ╔═╡ 7f64fa32-d9a4-4f4c-b53a-35423c7c9cf2
let
	figure = (; resolution = (600, 300))
	
	df_big = vcat(df, df_τ, source = "tax reform" => ["no", "yes"])
	
	@chain df_big begin
		data(_) * mapping(
			:k, :value,
			linestyle="tax reform",
			color=:income
		) * visual(Lines)
		draw(; figure)
	end
end

# ╔═╡ 04f6babd-4db0-45e9-8cc8-a09ce281e1bd
begin
	dfΔ = copy(df)
	dfΔ.Δ = Δ_CRRA.(df_τ.value, df.value, σ)
end;

# ╔═╡ 3520454b-ab40-4521-aeb5-463345d4422c
let
	figure = (; resolution = (600, 300))

	@chain dfΔ begin
		data(_) * mapping(:k, :Δ, color=:income) * visual(Lines)
		draw(; figure)
	end
end

# ╔═╡ 385b7e3e-83c1-4257-a35f-5d7b2b77ee73
let
	value   = mean(df.value,   weights(df.π₀))
	value_τ = mean(df_τ.value, weights(df_τ.π₀))
	Δ_CRRA(value_τ, value, σ)
end

# ╔═╡ a6245b74-2ceb-468c-b8a0-623d4b8abe36
let 
	Δ_z = zeros(n_y)
	df_groups   = groupby(df, :z)
	df_τ_groups = groupby(df_τ, :z)
	for i_y in 1:n_y
		df_z   = df_groups[i_y]
		df_τ_z = df_τ_groups[i_y]
		value   = mean(df_z.value,   weights(df_z.π₀))
		value_τ = mean(df_τ_z.value, weights(df_τ_z.π₀))
		Δ_z[i_y] = Δ_CRRA(value_τ, value, σ)
	end
	Δ_z
end

# ╔═╡ f54c97f9-bd22-4e81-966e-b68ef9e71efe
let

	# solve model in both stationary equilibria
	hh_sl = Household(; β=β, σ=σ_sl, m=m)

	y_trans_sl = [ρ_sl 1-ρ_sl; 1-ρ_sl ρ_sl]
	
	y_chain_sl   = MarkovChain(y_trans_sl, [y_1,     y_2])
	y_chain_τ_sl = MarkovChain(y_trans_sl, [y_1 + τ, y_2 - τ])

	ss_sl   = statespace(; k_vals, z_chain=y_chain_sl)
	ss_τ_sl = statespace(; k_vals, z_chain=y_chain_τ_sl)

	df_sl   = solve_PE(hh_sl, ss_sl,   prices, π₀)
	df_τ_sl = solve_PE(hh_sl, ss_τ_sl, prices, π₀)

	# compute conditional and unconditional welfare changes
	df_sl.Δ = Δ_CRRA.(df_τ_sl.value, df_sl.value, σ_sl)

	value   = mean(df.value,   weights(df.π₀))
	value_τ = mean(df_τ.value, weights(df_τ.π₀))
	Δ = Δ_CRRA.(value_τ, value, σ)

	value_sl   = mean(df_sl.value,   weights(df_sl.π₀))
	value_τ_sl = mean(df_τ_sl.value, weights(df_τ_sl.π₀))
	Δ_sl = Δ_CRRA.(value_τ_sl, value_sl, σ_sl)
	
	print("Δ₀ = ", round(Δ*100, digits=2), "%\n")
	print("Δ  = ",  round(Δ_sl*100, digits=2), "%")

	# plot conditional welfare changes
	figure = (; resolution = (600, 300))

	df_big = vcat(dfΔ, df_sl, source=:parameters => ["default", "sliders"])
	@chain df_big begin
		data(_) * mapping(
			:k, :Δ,
			linestyle=:parameters => "parameters",
			color=:income => nonnumeric => "income"
		) * visual(Lines)
		draw(; figure)
	end
end

# ╔═╡ c1f51283-f9e4-4169-a150-96423057618a
function net_asset_demand(hh, ss, r, π₀)
	prices  = (q = 1/(1+r), w = 1.0, Δr = 0.)
	df = solve_PE(hh, ss, prices, π₀)
	mean(df.k, weights(df.π))
end

# ╔═╡ 2baf5805-ad8d-49e0-a18e-4f5f69a05c1c
r_eq   = find_zero(
	r -> net_asset_demand(hh, ss,   r, π₀), 
	initial_bracket, Brent(),
	atol=1e-6, rtol=1e-6, xatol=1e-6, xrtol=1e-6
)

# ╔═╡ 7443becb-1a5b-46eb-a2df-bbd289c5bfe6
r_eq_τ = find_zero(
	r -> net_asset_demand(hh, ss_τ, r, π₀), 
	initial_bracket, Brent(),
	atol=1e-6, rtol=1e-6, xatol=1e-6, xrtol=1e-6
)

# ╔═╡ b8bf3582-d6a0-4a23-b080-a9b777893205
begin
	
	prices_eq    = (q = 1/(1+r_eq), w = 1.0, Δr = 0.)
	prices_τ_eq  = (q = 1/(1+r_eq_τ),    w = 1.0, Δr = 0.)
	
	
	df_eq     = solve_PE(hh, ss,   prices_eq, π₀)
	df_τ_noeq = solve_PE(hh, ss_τ, prices_eq, π₀)
	df_τ_eq = solve_PE(hh, ss_τ, prices_τ_eq, π₀)

	df_τ_noeq.Δ = Δ_CRRA.(df_τ_noeq.value, df_eq.value, σ)
	df_τ_eq.Δ   = Δ_CRRA.(df_τ_eq.value, df_eq.value, σ)

end;

# ╔═╡ dadd5f1a-3746-4fa9-87e4-00ed7e029a23
let
	value   = mean(df_eq.value,   weights(df_eq.π₀))
	value_τ = mean(df_τ_eq.value, weights(df_τ_eq.π₀))
	Δ_CRRA(value_τ, value, σ)
end

# ╔═╡ dbba6cdc-95be-44ce-8ea6-ccd1225dcd03
let
	figure = (; resolution = (600, 300))

	df_big = vcat(df_τ_noeq, df_τ_eq, source = :equilibrium => ["PE", "GE"])
	@chain df_big begin
		data(_) * mapping(
			:k, :Δ,
			linestyle=:equilibrium,
			color=:income
		) * visual(Lines)
		draw(; figure)
	end
end

# ╔═╡ e099f86b-3b8e-4783-9c80-84733cf174df
md"""
## Imported packages
"""

# ╔═╡ 1392f788-73b5-4733-b1d3-4fb5cc1c8c78
TableOfContents()

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
AlgebraOfGraphics = "cbdf2221-f076-402e-a563-3d30da359d67"
CairoMakie = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"
Chain = "8be319e6-bccf-4806-a6f7-6fae938471bc"
DataFrameMacros = "75880514-38bc-4a95-a458-c2aea5a3a702"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
QuantEcon = "fcd29c91-0bd7-5a09-975d-7ac3f643a60c"
Roots = "f2b01f46-fcfa-551c-844a-d8ac1e96c665"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
StatsBase = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"

[compat]
AlgebraOfGraphics = "~0.6.14"
CairoMakie = "~0.10.4"
Chain = "~0.5.0"
DataFrameMacros = "~0.4.1"
DataFrames = "~1.5.0"
PlutoUI = "~0.7.50"
QuantEcon = "~0.16.4"
Roots = "~2.0.13"
StatsBase = "~0.33.21"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.9.0-rc2"
manifest_format = "2.0"
project_hash = "739f4ed5a2f12fa6a7e192e287ffcc0405f4507b"

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

[[deps.ArnoldiMethod]]
deps = ["LinearAlgebra", "Random", "StaticArrays"]
git-tree-sha1 = "62e51b39331de8911e4a7ff6f5aaf38a5f4cc0ae"
uuid = "ec485272-7323-5ecc-a04f-4719b315124d"
version = "0.2.0"

[[deps.ArrayInterface]]
deps = ["Adapt", "LinearAlgebra", "Requires", "SnoopPrecompile", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "38911c7737e123b28182d89027f4216cfc8a9da7"
uuid = "4fba245c-0d91-5ea0-9b3e-6abc04ee57a9"
version = "7.4.3"

    [deps.ArrayInterface.extensions]
    ArrayInterfaceBandedMatricesExt = "BandedMatrices"
    ArrayInterfaceBlockBandedMatricesExt = "BlockBandedMatrices"
    ArrayInterfaceCUDAExt = "CUDA"
    ArrayInterfaceGPUArraysCoreExt = "GPUArraysCore"
    ArrayInterfaceStaticArraysCoreExt = "StaticArraysCore"
    ArrayInterfaceTrackerExt = "Tracker"

    [deps.ArrayInterface.weakdeps]
    BandedMatrices = "aae01518-5342-5314-be14-df237901396f"
    BlockBandedMatrices = "ffab5731-97b5-5995-9138-79e8c1846df0"
    CUDA = "052768ef-5323-5732-b1bb-66c8b64840ba"
    GPUArraysCore = "46192b85-c4d5-4398-a991-12ede77f4527"
    StaticArraysCore = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
    Tracker = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"

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

[[deps.BenchmarkTools]]
deps = ["JSON", "Logging", "Printf", "Profile", "Statistics", "UUIDs"]
git-tree-sha1 = "d9a9701b899b30332bbcb3e1679c41cce81fb0e8"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.3.2"

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

[[deps.CodecBzip2]]
deps = ["Bzip2_jll", "Libdl", "TranscodingStreams"]
git-tree-sha1 = "2e62a725210ce3c3c2e1a3080190e7ca491f18d7"
uuid = "523fee87-0ab8-5b00-afb7-3ecf72e48cfd"
version = "0.7.2"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "9c209fb7536406834aa938fb149964b985de6c83"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.1"

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

[[deps.CommonSubexpressions]]
deps = ["MacroTools", "Test"]
git-tree-sha1 = "7b8a93dba8af7e3b42fecabf646260105ac373f7"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.0"

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

[[deps.DSP]]
deps = ["Compat", "FFTW", "IterTools", "LinearAlgebra", "Polynomials", "Random", "Reexport", "SpecialFunctions", "Statistics"]
git-tree-sha1 = "da8b06f89fce9996443010ef92572b193f8dca1f"
uuid = "717857b8-e6f2-59f4-9121-6e50c889abd2"
version = "0.7.8"

[[deps.DataAPI]]
git-tree-sha1 = "e8119c1a33d267e16108be441a287a6981ba1630"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.14.0"

[[deps.DataFrameMacros]]
deps = ["DataFrames", "MacroTools"]
git-tree-sha1 = "5275530d05af21f7778e3ef8f167fb493999eea1"
uuid = "75880514-38bc-4a95-a458-c2aea5a3a702"
version = "0.4.1"

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

[[deps.DiffResults]]
deps = ["StaticArraysCore"]
git-tree-sha1 = "782dd5f4561f5d267313f23853baaaa4c52ea621"
uuid = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
version = "1.1.0"

[[deps.DiffRules]]
deps = ["IrrationalConstants", "LogExpFunctions", "NaNMath", "Random", "SpecialFunctions"]
git-tree-sha1 = "a4ad7ef19d2cdc2eff57abbbe68032b1cd0bd8f8"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.13.0"

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

[[deps.FiniteDiff]]
deps = ["ArrayInterface", "LinearAlgebra", "Requires", "Setfield", "SparseArrays", "StaticArrays"]
git-tree-sha1 = "03fcb1c42ec905d15b305359603888ec3e65f886"
uuid = "6a86dc24-6348-571c-b903-95158fe2bd41"
version = "2.19.0"

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
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions"]
git-tree-sha1 = "00e252f4d706b3d55a8863432e742bf5717b498d"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "0.10.35"
weakdeps = ["StaticArrays"]

    [deps.ForwardDiff.extensions]
    ForwardDiffStaticArraysExt = "StaticArrays"

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

[[deps.Graphs]]
deps = ["ArnoldiMethod", "Compat", "DataStructures", "Distributed", "Inflate", "LinearAlgebra", "Random", "SharedArrays", "SimpleTraits", "SparseArrays", "Statistics"]
git-tree-sha1 = "1cf1d7dcb4bc32d7b4a5add4232db3750c27ecb4"
uuid = "86223c79-3864-5bf0-83f7-82e725a168b6"
version = "1.8.0"

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

[[deps.IntegerMathUtils]]
git-tree-sha1 = "f366daebdfb079fd1fe4e3d560f99a0c892e15bc"
uuid = "18e54dd8-cb9d-406c-a71d-865a43cbb235"
version = "0.1.0"

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

[[deps.LineSearches]]
deps = ["LinearAlgebra", "NLSolversBase", "NaNMath", "Parameters", "Printf"]
git-tree-sha1 = "7bbea35cec17305fc70a0e5b4641477dc0789d9d"
uuid = "d3d80556-e9d4-5f37-9878-2ab0fcc64255"
version = "7.2.0"

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

[[deps.MathOptInterface]]
deps = ["BenchmarkTools", "CodecBzip2", "CodecZlib", "DataStructures", "ForwardDiff", "JSON", "LinearAlgebra", "MutableArithmetics", "NaNMath", "OrderedCollections", "PrecompileTools", "Printf", "SparseArrays", "SpecialFunctions", "Test", "Unicode"]
git-tree-sha1 = "8e054675d393ce5866dcdd6a071075e25e21a39c"
uuid = "b8f27783-ece8-5eb3-8dc8-9495eed66fee"
version = "1.15.1"

[[deps.MathProgBase]]
deps = ["LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "9abbe463a1e9fc507f12a69e7f29346c2cdc472c"
uuid = "fdba3010-5040-5b88-9595-932c9decdf73"
version = "0.7.8"

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

[[deps.MutableArithmetics]]
deps = ["LinearAlgebra", "SparseArrays", "Test"]
git-tree-sha1 = "3295d296288ab1a0a2528feb424b854418acff57"
uuid = "d8a4904e-b15c-11e9-3269-09a3773c0cb0"
version = "1.2.3"

[[deps.NLSolversBase]]
deps = ["DiffResults", "Distributed", "FiniteDiff", "ForwardDiff"]
git-tree-sha1 = "a0b464d183da839699f4c79e7606d9d186ec172c"
uuid = "d41bc354-129a-5804-8e4c-c37616107c6c"
version = "7.8.3"

[[deps.NLopt]]
deps = ["MathOptInterface", "MathProgBase", "NLopt_jll"]
git-tree-sha1 = "5a7e32c569200a8a03c3d55d286254b0321cd262"
uuid = "76087f3c-5699-56af-9a33-bf431cd00edd"
version = "0.6.5"

[[deps.NLopt_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9b1f15a08f9d00cdb2761dcfa6f453f5d0d6f973"
uuid = "079eb43e-fd8e-5478-9966-2cf3e3edb778"
version = "2.7.1+0"

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

[[deps.Optim]]
deps = ["Compat", "FillArrays", "ForwardDiff", "LineSearches", "LinearAlgebra", "NLSolversBase", "NaNMath", "Parameters", "PositiveFactorizations", "Printf", "SparseArrays", "StatsBase"]
git-tree-sha1 = "a89b11f0f354f06099e4001c151dffad7ebab015"
uuid = "429524aa-4258-5aef-a3af-852621145aeb"
version = "1.7.5"

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

[[deps.Polynomials]]
deps = ["LinearAlgebra", "RecipesBase"]
git-tree-sha1 = "434f66dfbb15606c49a7a21dc670119fdf729fa9"
uuid = "f27b6e38-b328-58d1-80ce-0feddd5e7a45"
version = "3.2.10"
weakdeps = ["ChainRulesCore", "MakieCore", "MutableArithmetics"]

    [deps.Polynomials.extensions]
    PolynomialsChainRulesCoreExt = "ChainRulesCore"
    PolynomialsMakieCoreExt = "MakieCore"
    PolynomialsMutableArithmeticsExt = "MutableArithmetics"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "a6062fe4063cdafe78f4a0a81cfffb89721b30e7"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.2"

[[deps.PositiveFactorizations]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "17275485f373e6673f7e7f97051f703ed5b15b20"
uuid = "85a6dd25-e78a-55b7-8502-1745935b8125"
version = "0.2.4"

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

[[deps.Primes]]
deps = ["IntegerMathUtils"]
git-tree-sha1 = "311a2aa90a64076ea0fac2ad7492e914e6feeb81"
uuid = "27ebfcd6-29c5-5fa9-bf4b-fb8fc14df3ae"
version = "0.5.3"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.Profile]]
deps = ["Printf"]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"

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

[[deps.QuantEcon]]
deps = ["DSP", "DataStructures", "Distributions", "FFTW", "Graphs", "LinearAlgebra", "Markdown", "NLopt", "Optim", "Pkg", "Primes", "Random", "SparseArrays", "SpecialFunctions", "Statistics", "StatsBase", "Test"]
git-tree-sha1 = "0069c628273c7a3b793383c7dc5f9744d31dfe28"
uuid = "fcd29c91-0bd7-5a09-975d-7ac3f643a60c"
version = "0.16.4"

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

[[deps.RecipesBase]]
deps = ["PrecompileTools"]
git-tree-sha1 = "5c3d09cc4f31f5fc6af001c250bf1278733100ff"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.3.4"

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
version = "5.4.0+0"

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
# ╟─1b5abb2b-5dc7-433c-9c83-6cfd06c8eadf
# ╟─a0825503-c132-4c12-93e2-60537d0f6085
# ╟─cc3fe476-950f-4351-8d12-4f5a8f359317
# ╟─77cfd0d8-5af0-417b-8161-f1c264ce20b4
# ╟─b8840490-5a17-44e2-8703-f9b845597111
# ╟─19978cfa-2798-475e-b057-083690b83b42
# ╠═28f1dbcd-1cbc-4c6c-9efe-9df2c0f5f881
# ╠═39b3e67f-ea18-4068-b63f-564f77ff237b
# ╠═3965321e-baaa-484d-a722-854201085e58
# ╟─520250f5-0877-4c36-a6f5-0b74a2916f37
# ╟─a7e67216-2bca-45d7-859b-b9e0328c4875
# ╟─a56f8765-cae6-40f4-aebf-900673ed9710
# ╠═23e83dbd-ad68-4b86-80a3-34c65ca420d1
# ╠═c8192e26-5215-4bbb-b1a7-da9df02b7e62
# ╠═b16d6fab-6bd1-4a39-a654-0fcb4ad868ee
# ╟─b40c8fdb-6d4b-4880-8e7c-523bdb95a847
# ╟─9c1e3401-5646-4b6e-a703-0b0d877bcd6b
# ╠═4eff64c0-16f1-48b0-87ec-d9f49599d0b0
# ╠═4bdd9050-87f7-4551-88d5-5c2cca569bb8
# ╟─fc6e8503-08bd-4df3-987e-2d926504ba34
# ╟─ef3ab9ee-ae95-4482-b17f-48c50c0fdcb9
# ╠═03439979-79cd-492d-a04e-bee96d67a9cb
# ╟─31a30781-59c9-4a56-be71-dd12626ae9ec
# ╠═d7b1e1a4-3153-4fb7-9908-55ce65d7fa2f
# ╟─a2030a1e-6da9-4f5f-a367-03cd98530d7c
# ╠═548005d3-e608-4e9f-af60-909394c8e67c
# ╟─c5cb959f-8c66-4084-9a53-4cf422cdf762
# ╟─b8ab52fc-07f2-4512-b477-df1e294d91a7
# ╠═7f64fa32-d9a4-4f4c-b53a-35423c7c9cf2
# ╟─9c1efccf-1235-472d-b395-10dc5494d114
# ╟─69004cfb-29ea-4757-8eb6-3e905da0b2cb
# ╟─0abcb92d-838a-4fa6-a1bb-5bc6d7499e85
# ╟─02d23829-b7f8-415d-aca1-b71992b72bdb
# ╟─59f22787-ab1e-4096-9e43-39f33ba42713
# ╟─66e4ff89-288c-4963-bb7d-8cfde20e42a0
# ╟─8c185d30-7de4-4273-a739-d2af1d46a3a8
# ╟─a453a9dc-0345-4630-8a75-e26a0de10e66
# ╟─3e5158e4-146e-4b68-a20a-9b315de51de3
# ╠═f6faaf5b-e7ca-4081-8faf-f2cf189e8ab4
# ╟─849308de-b2e9-4f97-a948-60341863e7f8
# ╟─c7ca1ce9-8621-4ae1-ab4a-c924d90745d6
# ╠═04f6babd-4db0-45e9-8cc8-a09ce281e1bd
# ╟─3520454b-ab40-4521-aeb5-463345d4422c
# ╟─4f1fd4c1-1369-4e33-8e49-7ec51d33051c
# ╟─f91d1b23-5670-4de4-81f4-cd72c0deb085
# ╟─db24325c-49d8-45f7-805c-65b58a85889a
# ╟─30682ba5-d144-4c4d-bd7f-da16d6bf68fd
# ╠═385b7e3e-83c1-4257-a35f-5d7b2b77ee73
# ╟─7af904d0-fc43-4986-a17a-2bc12d7913f6
# ╠═a6245b74-2ceb-468c-b8a0-623d4b8abe36
# ╟─fcafcc6c-cc23-4ae1-8ff3-5bebd4e1ec13
# ╟─1f192db7-0c79-42e9-b433-8d6f78bafee4
# ╟─8382365c-99a0-4c29-9917-3a1f5f0b5af4
# ╟─bb48a69b-72bd-4b50-848a-1b438555164c
# ╟─143aa896-fc61-450c-843d-88546e129abd
# ╟─24e51342-df5d-448a-a76f-18375af543aa
# ╟─8252bc6d-7303-4c67-9daa-f536b173cfde
# ╟─28762c0a-76a3-44e8-8a48-dbc57dec4282
# ╠═f54c97f9-bd22-4e81-966e-b68ef9e71efe
# ╟─6e641df2-8b5b-49d8-88fc-36fa4b44b6e5
# ╟─d83a55d6-2901-4539-9ebb-3b16ecb02a3d
# ╟─d748feac-e583-4028-b3aa-6d1ac692255b
# ╟─5be45b08-726c-453b-b025-cf7f69f941ff
# ╠═d24ef390-0824-4c03-b1a9-236b8a982a92
# ╠═c1f51283-f9e4-4169-a150-96423057618a
# ╠═afe1dfa0-7b61-4a7b-a98c-e3ffce756591
# ╠═2baf5805-ad8d-49e0-a18e-4f5f69a05c1c
# ╠═7443becb-1a5b-46eb-a2df-bbd289c5bfe6
# ╟─24961de2-8e9a-4fd5-b6bf-8c0ccbd9d9a1
# ╟─28599228-417f-404f-bf3d-15ae388aff3b
# ╟─54887913-20f4-48c8-ae1a-8ae623ee44ee
# ╟─281fca35-1d20-417a-8928-ddd81c32b305
# ╠═b8bf3582-d6a0-4a23-b080-a9b777893205
# ╟─d379a396-0735-4fc9-aa6c-190d69a00fb0
# ╠═dadd5f1a-3746-4fa9-87e4-00ed7e029a23
# ╠═dbba6cdc-95be-44ce-8ea6-ccd1225dcd03
# ╟─23695e8e-9e3a-4519-bcef-82094833dcd9
# ╟─8cde58db-b774-4348-9ae1-25791a20a997
# ╟─18b470fa-d747-4ac2-a5aa-01f7671499a8
# ╟─cbcf8f08-0330-4458-ba7d-eb35f0d6b120
# ╟─a7130a4b-fb28-420e-b3a2-b0fd57532ce8
# ╠═9c4eeb4c-bc2c-428e-9c5b-d1424e7d42fe
# ╠═96b42aa6-8700-42d1-a4a1-949595549e4b
# ╠═ce25751c-949a-4ad3-a572-679f403ccb98
# ╠═d60367db-cf92-4c0a-aea4-eddb6552e2c8
# ╠═e3930baf-0560-4994-a637-7cb1923ce33c
# ╠═32f46a06-0832-479e-a00b-346cab1f8f5f
# ╠═13fbec57-6ebe-456e-bfc9-ee98ce85d09e
# ╟─5954bfdf-d8c3-48b9-9871-5e2ed6d77e1d
# ╠═c1ec949c-c6ba-43e5-a6b3-3e40f499a6ca
# ╟─e099f86b-3b8e-4783-9c80-84733cf174df
# ╠═1392f788-73b5-4733-b1d3-4fb5cc1c8c78
# ╠═7931c043-9379-44f9-bab2-6d42153aa3d3
# ╠═9df5eb89-7ff6-4749-b3c1-4199e22d1d07
# ╠═b9db33eb-bb0c-4510-8c7e-2aad8b30de5e
# ╠═dfa54f23-8141-4270-8344-08975d90322d
# ╠═719dce77-eb0f-4ebb-b6c5-eb8911e842a4
# ╠═d730d979-21ae-4c00-820f-b481b8b5cd4a
# ╠═41f783a0-5cfa-4c83-a66c-37243170d01b
# ╠═a11be816-ceef-4986-b313-6d429c8231be
# ╠═7575ffb0-ee67-48e8-8682-55385d40b50e
# ╠═6b8b0739-af1a-4ee9-89f1-291afdc47980
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
