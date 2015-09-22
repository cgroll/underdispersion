##########################
## simulation functions ##
##########################

function simIIDVals_norm(logPricesTn::Timenum, nPaths::Int = 1)
    # logPricesTn should be only one asset
    nObs, nAss = size(logPricesTn)
    
    if nAss != 1
        error("Original data must be exactly one asset.")
    end
    
    # get logRets
    logRets = price2ret(logPricesTn, log=true)
    
    ## get returns without NAs
    pureRets = dropna(logRets.vals[1])
    nRets = size(pureRets, 1)
    
    # get moments
    muHat = mean(pureRets)
    sigmaHat = std(pureRets)
    
    simRetsDf = DataFrame()
    noNAInds = !isna(logRets.vals[1])
    for ii=1:nPaths
        # simulate values
        simVals = simNormRets(nRets, muHat, sigmaHat)
        
        ## fill values into DataArray
        simRetsDa = DataArray(Float64, nObs-1)
        simRetsDa[noNAInds] = simVals
        
        ## copy values to DataFrame
        simRetsDf[ii] = simRetsDa
    end
    
    ## fix names
    if nPaths == 1
        colName = symbol(string(names(logPricesTn.vals)[1], "_sim"))
        rename!(simRetsDf, :x1, colName)
    else
        nams = [symbol(string(names(logPricesTn.vals)[1], "_sim$ii")) for ii=1:nPaths]
        names!(simRetsDf, nams)
    end
    
    simRets = Timenum(simRetsDf, idx(logRets))
    simPrices = ret2price(simRets)
    idx(simPrices)[1] = idx(logPricesTn)[1]
    
    return (simRets, simPrices)
end

function simNormRets(nRets::Int, mu::Float64, sigma::Float64)
    return randn(nRets)*sigma + mu
end

###########################
## aggregation functions ##
###########################

## get number of possible aggregated returns
##------------------------------------------

function countNumbRets(nRets::Int, minAggrDays::Int, maxAggrDays::Int)
    # determine number of aggregated returns
    counter = 0
    for ii=1:nRets
        for jj=ii:nRets
            if (jj-ii + 1) > minAggrDays
                if (jj-ii + 1) > maxAggrDays
                    break
                end
                counter += 1
            end
        end
    end
    return counter
end

function calcNumbRets(nRets::Int, minAggrDays::Int, maxAggrDays::Int)
    # 51 obs, 50 window -> 2 overlapping returns
    ## nAggrSamples = nRets - windowLength + 1
    nAggrSamples = [nRets - windowLength + 1
                    for windowLength in (minAggrDays+1):1:maxAggrDays]
    return sum(nAggrSamples)
end

## get aggregated returns
##-----------------------

function getAggrRets_unsorted(logRets::AbstractTimenum,
                              minAggrDays::Int = 100,
                              maxAggrDays::Int = 600)
    # eliminate NAs
    rets = asArr(narm(logRets), Float64)[:]
    nRets = length(rets)
    
    numbRets = calcNumbRets(nRets, minAggrDays, maxAggrDays)
    
    # preallocation
    aggrRets = zeros(numbRets, 2)
    
    counter = 1
    for ii=1:nRets
        firstSumKnown = false
        for jj=ii:nRets
            if (jj-ii + 1) > minAggrDays
                if (jj-ii + 1) > maxAggrDays
                    break
                end
                if !firstSumKnown
                    aggrRets[counter, 1] = jj-ii+1
                    aggrRets[counter, 2] = sum(rets[ii:jj])
                    firstSumKnown = true
                    counter += 1
                else
                    aggrRets[counter, 1] = jj-ii+1
                    aggrRets[counter, 2] = aggrRets[counter - 1, 2] + rets[jj]
                    counter += 1
                end
            end
        end
    end
    
    # drop unneccessarily preallocated rows
    ## aggrRets = aggrRets[aggrRets[:, 1] .!= 0, :]
    return aggrRets
end

function getAggrRets(logRets::AbstractTimenum,
                     minAggrDays::Int = 100,
                     maxAggrDays::Int = 600)
    # eliminate NAs
    rets = asArr(narm(logRets), Float64)[:]
    nRets = length(rets)
    
    numbRets = calcNumbRets(nRets, minAggrDays, maxAggrDays)
    
    # preallocation
    aggrRets = zeros(numbRets, 2)
    
    counter = 1
    firstSumUnknown = true
    for windowLength in (minAggrDays+1):1:maxAggrDays
        firstSumUnknown = true
        for ii=1:(nRets-windowLength+1)
            if (ii+windowLength-1) < nRets
                if firstSumUnknown
                    aggrRets[counter, 1] = windowLength
                    aggrRets[counter, 2] = sum(rets[ii:(ii+windowLength-1)])
                    firstSumUnknown = false
                    counter += 1
                else
                    aggrRets[counter, 1] = windowLength
                    aggrRets[counter, 2] = aggrRets[counter - 1, 2] +
                    rets[ii+windowLength-1] - rets[ii-1]
                    counter += 1
                end
            end
        end
    end
    return aggrRets
end

## get quantiles from array of aggregated returns
##-----------------------------------------------

function getAggrRetQuantiles_slow(aggrRets::Array{Float64, 2},
                             quants::Array{Float64, 1}=[0.01; 0.05; 0.1; 0.3; 0.5; 0.7; 0.9; 0.95; 0.99])

    # get unique time horizons
    horizons = sort(unique(aggrRets[:, 1]))
    
    nHor = length(horizons)
    nQuants = length(quants) + 2
    
    retQuants = zeros(nHor, nQuants)
    for ii=1:nHor
        # get all associated returns
        currHor = horizons[ii]
        associatedRetsInds = aggrRets[:, 1] .== currHor
        associatedRets = aggrRets[:, 2][associatedRetsInds]
        
        # get quantiles
        horQuants = quantile(associatedRets, quants)
        horQuants = [minimum(associatedRets); horQuants; maximum(associatedRets)]
        
        # save results
        retQuants[ii, :] = horQuants
    end
    return Timematr(retQuants, horizons)
end

function getAggrRetQuantiles(aggrRets::Array{Float64, 2},
                             quants::Array{Float64, 1}=[0.01; 0.05; 0.1; 0.3; 0.5; 0.7; 0.9; 0.95; 0.99])

    # get unique time horizons
    horizons = unique(aggrRets[:, 1])
    nHor = length(horizons)
    nQuants = length(quants) + 2
    nRets = size(aggrRets, 1)
    
    retQuants = zeros(nHor, nQuants)
    intervalBeg = 1
    intervalEnd = 1
    counter = 1
    currHor = aggrRets[1, 1]
    for ii=1:nRets
        ## treat last observation separately
        if ii == nRets 
            intervalEnd = ii
            associatedRets = aggrRets[intervalBeg:intervalEnd, 2]
            horQuants = quantile(associatedRets, quants)
            retQuants[counter, :] = [minimum(associatedRets);
    horQuants; maximum(associatedRets)]
            counter += 1
            break
        else
            ## get quantiles whenever next observation is of different
            ## time horizon
            if aggrRets[ii + 1, 1] != currHor
                intervalEnd = ii
                associatedRets = aggrRets[intervalBeg:intervalEnd, 2]
                horQuants = quantile(associatedRets, quants)
                retQuants[counter, :] = [minimum(associatedRets);
                                         horQuants; maximum(associatedRets)]
                counter += 1
                intervalBeg = ii+1
                currHor = aggrRets[intervalBeg, 1]
            end
        end
    end

    nams = [:min; Symbol[symbol(string("q_", 100*quant, "%")) for quant in
                         quants]; :max]
    
    return Timematr(retQuants, nams, horizons)
end

##############
## drawdown ##
##############

function drawdown(logPrices::Array{Float64, 1})
    nObs = size(logPrices, 1)
    histMax = -Inf
    histMaxInd = NaN
    dd = zeros(nObs, 1)
    ddStreak = zeros(nObs, 1)
    for ii=1:nObs
        if isnan(logPrices[ii])
            if ii == 1
                dd[ii] = 0
                ddStreak[ii] = 0
            else
                dd[ii] = dd[ii-1]
                ddStreak[ii] = ddStreak[ii-1] # only count trading days
            end
        else
            if logPrices[ii] >= histMax
                dd[ii] = 0
                ddStreak[ii] = 0
                histMax = logPrices[ii]
                histMaxInd = ii
            else
                dd[ii] = histMax - logPrices[ii]
                ddStreak[ii] = ii - histMaxInd
            end
        end
    end
    return (dd, ddStreak)
end

function drawdown(logPricesTn::Timenum)
    nObs, nAss = size(logPricesTn)
    dds = zeros(nObs, nAss)
    ddStreaks = zeros(nObs, nAss)
    for ii=1:nAss
        dd, ddStreak = drawdown(asArr(logPricesTn[:, ii], Float64, NaN)[:])
        dds[:, ii] = dd
        ddStreaks[:, ii] = ddStreak
    end
    ddTm = Timematr(dds, names(logPricesTn), idx(logPricesTn))
    ddStreakTm = Timematr(ddStreaks, names(logPricesTn), idx(logPricesTn))
    return (ddTm, ddStreakTm)
end

########################
## plotting functions ##
########################

function plotEvolution(tn::Timenum)

    tn = narowrm(tn)

    # should be called with two assets
    nams = names(tn)

    ## get first date as title
    firstDate = idx(narm(tn[1]))[1]
    dateString = string(year(firstDate), "-",
                        month(firstDate), "-",
                        day(firstDate))
    
    # get values without NAs
    yVals1 = asArr(tn[1], Float64, NaN)
    yVals2 = asArr(tn[2], Float64, NaN)
    
    nRets = length(yVals1)
    xVals = [1:nRets]
    
    dataDf = composeDataFrame([xVals yVals1 yVals2], [:Idx; nams])
    
    ticks = [0:300:nRets]
    
    stackedData = stack(dataDf, nams)
    p1 = Gadfly.plot(stackedData, x="Idx", y="value",
                     color="variable", Gadfly.Geom.line,
                     Gadfly.Guide.xticks(ticks=ticks)
                     ## Gadfly.Guide.title(dateString)
                     )


    vals = [yVals1 yVals2]
    dats = dat2num(tn)
    df = composeDataFrame([dats vals], [:Idx; nams])
    stackedData = stack(df, nams)
    ticks = [minimum(dats)
             ceil(minimum(dats)):1:floor(maximum(dats))
             maximum(dats)]
    ticks = [ceil(minimum(dats)):1:floor(maximum(dats))]

    p2 = Gadfly.plot(stackedData, x="Idx", y="value",
                     color="variable",
                     Guide.xticks(ticks=ticks, orientation=:vertical),
                     Gadfly.Geom.line,
                     ## Scale.x_continuous(minvalue=minimum(dats),
                                        ## maxvalue=maximum(dats)),
                     )
    
    return Gadfly.hstack(p1, p2)
end

function plotAggrRets(logRets::AbstractTimenum,
                      minAggrDays::Int = 100,
                      maxAggrDays::Int = 600)
    # should be applied to single stock only
    
    aggrRets = getAggrRets(logRets, minAggrDays, maxAggrDays)
    
    return Gadfly.plot(x=aggrRets[:, 1],
                       y=aggrRets[:, 2],
                       Gadfly.Geom.hexbin(xbincount = 100, ybincount = 100))
end

function plotAggrRets(aggrRets::Array{Float64, 2})
    return Gadfly.plot(x=aggrRets[:, 1],
                       y=aggrRets[:, 2],
                       Gadfly.Geom.hexbin(xbincount = 100, ybincount = 100))
end

function plotQuants(horQuants::Timematr)
    nams = names(horQuants)
    vals = asArr(horQuants)
    
    dataDf = composeDataFrame([idx(horQuants) vals], [:Horizons; nams])
    
    stackedData = stack(dataDf, nams)
    return Gadfly.plot(stackedData, x="Horizons", y="value",
    color="variable", Gadfly.Geom.line
    ## Scale.color_discrete_manual(colorant"red",colorant"purple",colorant"green")
                )
end
