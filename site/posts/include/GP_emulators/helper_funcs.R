run_SS_sim <- function(inputs){
  this.setup <- set_trait_model(no_sp = no_sp, 
                                r_pp = inputs$r_pp,
                                kappa = 0.01,
                                h=inputs$h,
                                beta = 300,
                                sigma= inputs$sigma,
                                q=0.9,#inputs$q,
                                p=0.75,#inputs$p,
                                n=2/3,#inputs$n,
                                f_0 = 0.8,
                                min_w_inf = min_w_inf, 
                                max_w_inf = max_w_inf,
                                knife_edge_size = knife_edges)
  
  this.sim <- project(this.setup, t_max = 100, dt=0.2, effort = 0.4)
  this.biom <- colMeans(getBiomass(this.sim)[75:100,])
  this.biom
}

input_reg <- function(inputs) {
  out <- cbind(1,inputs,inputs^2,inputs^3)
  rownames(out) <- sprintf('input %d',1:nrow(as.matrix(inputs)))
  as.matrix(out)
}


output_reg <- function(outputs) {
  out <- cbind(1,outputs,outputs^2,outputs^3)
  rownames(out) <- sprintf('outputs %d',1:nrow(as.matrix(outputs)))
  as.matrix(out)
}


require(emulator)

input_var <- function(inputs,finputs=NULL) {
  cmat <- corr.matrix(inputs,yold=finputs,scales=rep(1,ncol(inputs)))
  if(!is.null(finputs)) cmat <- t(cmat)
  cmat
}


define_OPE <- function(scales, inData, outGrid, outData, opt=F){
  
  input_var <- function(inputs,finputs=NULL) {
    cmat <- corr.matrix(inputs,yold=finputs,scales=exp(scales[2:(ncol(inputs)+1)]))
    if(!is.null(finputs)) cmat <- t(cmat)
    cmat
  }
  
  output_var <- corr.matrix(as.matrix(outGrid),scales=exp(scales[1]))
  output_regs <- output_reg(outGrid)
  
  vr <- ncol(input_reg(inData))
  vs <- ncol(output_regs)
  ms <- rep(0, vr * vs)
  V <- diag(1^2, vr * vs)
  a <- 1
  d <- 1
  NIG <- list(m = ms, V = V, a = a, d = d)
  
  OPE <- initOPE(gr = input_reg, 
                 kappar = input_var, 
                 Gs = output_regs , 
                 Ws = output_var, 
                 NIG = NIG)
  
  OPE <- adjustOPE(OPE, R = inData, Y = outData)
  if(opt) {
    return(marlikOPE(OPE))
  } else {
    OPE
  }
  
}

m <- as.matrix
stdise <- function(x) apply(x,2,function(y) (y-mean(y))/sd(y))
stdise_wrt <- function(x,z) sapply(1:ncol(x), function(y) (x[,y]-mean(z[,y]))/sd(z[,y]))

#rev_stdise <- function(y) apply(y,2,function(x) x*sd(x)+mean(x))
rev_stdise_wrt <- function(y,z) sapply(1:ncol(y), function(x) y[,x]*sd(z[,x])+mean(z[,x]))

emulate <- function(ins,emulator,split=F,rev_std_out=T,rev_std_data=NULL){
  
  this.pred <- predictOPE(emulator, Rp = as.matrix(ins), type='EV')
  if (rev_std_out) this.pred$mu <- rev_stdise_wrt(this.pred$mu,rev_std_data)
  dim(this.pred$Sigma) <- rep(length(this.pred$mu),2)
  out <- data.frame(mu=as.vector(this.pred$mu),
                    sigma=diag(this.pred$Sigma),
                    ind = 1:nrow(this.pred$mu))
  out <- arrange(out,ind)
  if (split) out <- split(out,as.factor(out$ind))
 
  out
}