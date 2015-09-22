module test_utils

using Base.Test

include("../src/sim_vals.jl")
## include("./src/sim_vals.jl")

@test calcNumbRets(6300, 100, 600) == countNumbRets(6300, 100, 600)

normedPrices =
    readTimedata("market_risk_data/processed_data/normedPrices.csv")

logRets = price2ret(normedPrices, log=true);

@time aggrRets = getAggrRets(logRets[1])
@time aggrRets2 = getAggrRets_unsorted(logRets[1])

aggrRets_101 = aggrRets[aggrRets[:, 1] .== 101, :]
aggrRets2_101 = aggrRets2[aggrRets2[:, 1] .== 101, :]

@test sortrows(aggrRets_101) == sortrows(aggrRets2_101)

@time outputSlow = getAggrRetQuantiles_slow(aggrRets)
@time outputFast = getAggrRetQuantiles(aggrRets)

end
