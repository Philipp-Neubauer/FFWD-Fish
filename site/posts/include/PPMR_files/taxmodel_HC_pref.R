model{
  for(p in PREY){
    #log_ten_Prey[p]~dsum(log_ten_Prey_pref[p],log10())
    log_ten_Prey[p] ~ dnorm(mu[p],tau)
    mu[p] <- betas[1:NCOVS] %*% COVS[p,1:NCOVS] + txfx[ind[p]] + habfx[habitat[p]] + feedtypefx[feedtype[p]] + geoareafx[geoarea[p]]
  }
  
  #need jags 4.0 for indexing
  for(q in PREYA){
    #log_ten_Prey[q]~dsum(log_ten_Prey_pref[q],log10())
    log_ten_Prey_pred[q] ~ dnorm(mu_pred[q],tau)
    mu_pred[q] <- betas[1:NCOVS] %*% COVS[q,1:NCOVS] + txfx[ind[q]] + habfx[habitat[q]] + feedtypefx[feedtype[q]] + geoareafx[geoarea[q]]
  }
  
  #pref <- exp(l_obs)/exp(l_obs)^-2
  l_obs ~ dnorm(betas[1],tau)
  
  for (c in 1:NCOVS){
    betas[c] ~ dnorm(0,1e-10)
    #ARDtau[c] ~ dgamma(0.001,0.001)
  }
  
  for (h in 1:HABITATS){
    habfx[h] <- hab.xi*hab.eta[h] 
    hab.eta[h] ~ dnorm(0,hab.prec)
  }
  
  for (ft in 1:FEEDTYPES){
    feedtypefx[ft] <- ft.xi*ft.eta[ft] 
    ft.eta[ft] ~ dnorm(0,ft.prec)
  }
  
  for (d in 1:GEOAREAS){
    geoareafx[d] <- geo.xi*geo.eta[d] 
    geo.eta[d] ~ dnorm(0,geo.prec)
  }
  
  ### Taxonomic fx
  # individual fx from species distribution
  for(i in 1:NIND){
    txfx[i] <- speciesmu[species[i]]+species.xi[species[i]]*ind.eta[i]
    # species tau drawn from hierarchical distr over all families
    ind.eta[i] ~ dnorm(0,species.prec)
  }
  
  # species fx from family distribution
  for(s in 1:NSPECIES){
    # species mean drawn from family dist
    speciesmu[s] <- familymu[family[s]]+family.xi[family[s]]*species.eta[s]
    l_obs_sp[s] ~ dnorm(betas[1]+speciesmu[s]+species.xi[s]*sp_pred.eta[s],tau)
    # species tau drawn from hierarchical distr over all families
    sp_pred.eta[s] ~ dnorm(0,species.prec)
    species.eta[s] ~ dnorm(0,family.prec)
    species.xi[s] ~ dnorm(0,species.scale^-2)
  }
  
  # family fx from order distribution
  for(f in 1:NFAMILIES){
    # family mean drawn from order dist
    familymu[f] <- ordermu[order[f]]+order.xi[order[f]]*family.eta[f]
    l_obs_fam[f] ~ dnorm(betas[1]+familymu[f]+family.xi[f]*fam_pred.eta[f],tau)
    # family tau drawn from hierarchical distr over all families
    fam_pred.eta[f] ~ dnorm(0,family.prec)
    family.eta[f] ~ dnorm(0,order.prec)
    family.xi[f] ~ dnorm(0,family.scale^-2)
  }
  
  # order fx from class distribution
  for(o in 1:NORDERS){
    # order mean drawn from order dist
    ordermu[o] <- classmu[class[o]]+class.xi[class[o]]*order.eta[o]
    l_obs_ord[o] ~ dnorm(betas[1]+ordermu[o]+order.xi[o]*ord_pred.eta[o],tau)
    # order tau drawn from hierarchical distr over all orders
    ord_pred.eta[o] ~ dnorm(0,order.prec)
    order.eta[o] ~ dnorm(0,class.prec)
    order.xi[o] ~ dnorm(0,order.scale^-2)
  }
  
  # order fx from class distribution
  for(cl in 1:NCLASSES){
    # order mean drawn from order dist
    classmu[cl] <- grandmu+grand.xi*class.eta[cl]
    l_obs_cl[cl] ~ dnorm(betas[1]+classmu[cl]+class.xi[cl]*cl_pred.eta[cl],tau)
    cl_pred.eta[cl] ~ dnorm(0, class.prec)
    class.eta[cl] ~ dnorm(0, grand.prec)
    # order tau drawn from hierarchical distr over all orders
    class.xi[cl] ~ dnorm(0,class.scale^-2)
    #sigma.class[cl] <- abs(class.xi[cl])/sqrt(class.prec) 
  }
  
  # priors tax hierachy
  species.scale ~ dgamma(10,3)
  species.prec ~ dgamma(0.5,0.5)
  
  family.scale  ~ dgamma(10,3)
  family.prec ~ dgamma(0.5,0.5)
  
  order.scale   ~ dgamma(10,3)
  order.prec ~ dgamma(0.5,0.5)
  
  class.scale ~ dgamma(10,3)
  class.prec ~ dgamma(0.5,0.5)
  
  grand.xi ~ dnorm(0,1)
  grand.prec ~ dgamma(0.5,0.5)
  #sigma.grand <- abs(grand.xi)/sqrt(grand.prec) 
  
  grandtau ~ dgamma(0.001,0.001)
  grandmu <- 0
  
  # other rfx 
  geo.xi ~ dnorm(0,1)
  geo.prec ~ dgamma(0.5,0.5)
  
  ft.xi ~ dnorm(0,1)
  ft.prec ~ dgamma(0.5,0.5)
  
  hab.xi ~ dnorm(0,1)
  hab.prec ~ dgamma(0.5,0.5)
  
  # finite population sds
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