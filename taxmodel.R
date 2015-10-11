model{
  for(p in 1:PREY){
    log_ten_Prey[p] ~ dnorm(mu[p],tau)
    mu[p] <- betas[1:NCOVS] %*% COVS[p,1:NCOVS] + txfx[ind[p]] + habfx[habitat[p]] + feedtypefx[feedtype[p]] + geoareafx[geoarea[p]]
  }
  
  for (c in 1:NCOVS){
    betas[c] ~ dnorm(0,0.00001)
    #ARDtau[c] ~ dgamma(0.001,0.001)
  }
  
  for (h in 1:HABITATS){
    habfx[h] ~ dnorm(0,habitattau)
  }
  
  for (ft in 1:FEEDTYPES){
    feedtypefx[ft] ~ dnorm(0,feedtypetau)
  }
  
  for (d in 1:GEOAREAS){
    geoareafx[d] ~ dnorm(0,geoareatau)
  }
  
  ### Taxonomic fx
  # individual fx from species distribution
  for(i in 1:NIND){
    txfx[i] ~ dnorm(speciesmu[species[i]],speciestau[species[i]])
  }
  
  # species fx from family distribution
  for(s in 1:NSPECIES){
    # species mean drawn from family dist
    speciesmu[s] ~ dnorm(familymu[family[s]],familytau[family[s]])
    # species tau drawn from hierarchical distr over all species
    speciestau[s] ~ dgamma(0.001,0.001)#dgamma(speciesa,speciesb)
  }
  
  # family fx from order distribution
  for(f in 1:NFAMILIES){
    # family mean drawn from order dist
    familymu[f] ~ dnorm(ordermu[order[f]],ordertau[order[f]])
    # family tau drawn from hierarchical distr over all families
    familytau[f] ~ dgamma(0.001,0.001)#dgamma(familya,familyb)
  }
  
  # order fx from class distribution
  for(o in 1:NORDERS){
    # order mean drawn from order dist
    ordermu[o] ~ dnorm(classmu[class[o]],classtau[class[o]])
    # order tau drawn from hierarchical distr over all orders
    ordertau[o] ~ dgamma(0.001,0.001)#dgamma(ordera,orderb)
  }
  
  # order fx from class distribution
  for(cl in 1:NCLASSES){
    # order mean drawn from order dist
    classmu[cl] ~ dnorm(grandmu,grandtau)
    # order tau drawn from hierarchical distr over all orders
    classtau[cl] ~ dgamma(0.001,0.001)#dgamma(classa,classb)
  }
  
  # priors tax hierachy
#   speciesa ~ dgamma(0.001,0.001)
#   speciesb ~ dgamma(0.001,0.001)
#   familyb  ~ dgamma(0.001,0.001)
#   familya  ~ dgamma(0.001,0.001)
#   ordera   ~ dgamma(0.001,0.001)
#   orderb   ~ dgamma(0.001,0.001)
#   classa   ~ dgamma(0.001,0.001)
#   classb   ~ dgamma(0.001,0.001)
  grandtau ~ dgamma(0.001,0.001)
  
  grandmu <- 0
  
  # other rfx 
  geoareatau ~ dgamma(0.001,0.001)
  feedtypetau ~ dgamma(0.001,0.001)
  habitattau ~ dgamma(0.001,0.001)
  
  # finite populationd sds
  sd.ind     <- sd(txfx)
  sd.species <- sd(speciesmu)
  sd.family  <- sd(familymu)
  sd.order   <- sd(ordermu)
  sd.class   <- sd(classmu)
  sd.geoareafx    <- sd(geoareafx)
  sd.habfx   <- sd(habfx)
  sd.feedtypefx <- sd(feedtypefx)
  
  tau ~ dgamma(0.00001,0.00001)
}