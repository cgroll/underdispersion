########################
## set up environment ##
########################

## set working directory
cd("./mount/")

## load packages
##--------------

using DataFrames
using TimeData
using Econometrics
using DataArrays
using Gadfly

loadPlotting()

## load data
##----------

normedPrices =
    readTimedata("market_risk_data/processed_data/normedPrices.csv")

logRets = price2ret(normedPrices, log=true);

## get dimensions
nObs, nAss = size(normedPrices)

## load function src code
##-----------------------

include("./src/sim_vals.jl")

###########################
## create visualizations ##
###########################

## pick single asset
for chosenStock=6:20
    realPrices = normedPrices[chosenStock]

    ## simulate returns
    nSim = 2
    simRets, simPrices = simIIDVals_norm(realPrices, nSim)

    for chosenSim=1:nSim
        ## plot price evolutions
        pEvol = plotEvolution([realPrices simPrices[chosenSim]]);
        ## draw(PDF("pics/test_evolution.pdf", 18cm, 12cm), pEvol)

        ## plot aggregated returns distribution
        aggrRets_real = getAggrRets(logRets[chosenStock])
        aggrRets_sim = getAggrRets(simRets[chosenSim])
        pDistr_real = plotAggrRets(aggrRets_real);
        pDistr_sim = plotAggrRets(aggrRets_sim);

        ## plot return quantiles
        retQuants_real = getAggrRetQuantiles(aggrRets_real)
        retQuants_sim = getAggrRetQuantiles(aggrRets_sim)
        pQuants_real = plotQuants(retQuants_real);
        pQuants_sim = plotQuants(retQuants_sim);

        ## drawdown
        dd, ddStreak = drawdown(realPrices)
        dd_sim, ddStreak_sim = drawdown(simPrices[chosenSim])

        pDD = gdfPlot([dd dd_sim]);

        pDDStreak = Gadfly.plot(x = ddStreak.vals[1], y = dd.vals[1],
                                Gadfly.Geom.point(),
                                Scale.x_continuous(format=:plain),
                                Gadfly.Theme(default_point_size=Gadfly.Measure(0.5)));

        pDDStreak_sim = Gadfly.plot(x = ddStreak_sim.vals[1],
                                    y = dd_sim.vals[1], Gadfly.Geom.point(),
                                    Scale.x_continuous(format=:plain),
                                    Gadfly.Theme(default_point_size=Gadfly.Measure(0.5)));

        ## create figure name
        stockName = string(names(realPrices)[1])
        picName = string("pics/", stockName, "_sim_", string(chosenSim), ".pdf")
        
        draw(PDF(picName, 30cm, 50cm),
             vstack(pEvol,
                    hstack(pDistr_real, pDistr_sim),
                    hstack(pQuants_real, pQuants_sim),
                    hstack(pDDStreak, pDDStreak_sim)
                    )
             )

    end
end


####################################
## aggregated return distribution ##
####################################

for chosenStock=11:nAss
    display(chosenStock)
    realPrices = normedPrices[chosenStock]

    ## simulate returns
    nSim = 1
    simRets, simPrices = simIIDVals_norm(realPrices, nSim)

    for chosenSim=1:nSim
        ## plot aggregated returns distribution
        aggrRets_real = getAggrRets(logRets[chosenStock])
        aggrRets_sim = getAggrRets(simRets[chosenSim])
        pDistr_real = plotAggrRets(aggrRets_real);
        pDistr_sim = plotAggrRets(aggrRets_sim);

        stockName = string(names(realPrices)[1])
        picName = string("pics/aggrRetDistr", stockName, ".png")
        picNameSim = string("pics/aggrRetDistr", stockName, "_sim", ".png")

        draw(PNG(picName, 10cm, 10cm), pDistr_real)
        draw(PNG(picNameSim, 10cm, 10cm), pDistr_sim)
    end
end

#################
## square-root ##
#################

a = 0.25
grid = [0.01:0.1:10]
yVals = -sqrt(grid) + a*grid
plot(x=grid, y=yVals, Geom.point)
