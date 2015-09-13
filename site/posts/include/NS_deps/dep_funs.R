getGrowth  <- function (param,S,step){
  require(deSolve)

  t <- param$tEnd
  w <- S$w
  
  iPlot <- round(S$nSave*t/param$tEnd);
  idxRange <- floor(iPlot/2):iPlot;
  
  tRange <- seq(0,50,by= step)
  hbar <- param$alpha*param$f0*param$h-param$ks
  
  
  if (length(hbar) == 1){
    hbar = hbar * matrix(1,param$nSpecies);
  }
  state <- param$w0
  # Ode solver 
  deriv <-function(t, state, parameters) {
    with(as.list(c(state, parameters)),{
      # rate of change
      dX <- interp1(w,g,state)
      # return the rate of change
      list(dX)
    }) 
  }
  
  wCalc <- matrix(NA,param$nSpecies,length(tRange))
  for (i in 1:param$nSpecies){
    g = colMeans(S$g[idxRange,i,])
    
    SolveG = ode(y = param$w0,times = tRange, func = deriv, parms = c(g,w))
    wCalc[i,] <- SolveG[,2]/param$wInf[i]
  }
  
  w50 <- apply(wCalc,1,function(x) which.min((x-0.5)^2)*step)
  
  return(w50)
}

vanBGrowth <- function(data,step){
  dfVonB <- data[which(is.na(data$k) == 0),]
  dfVonB$Linf <- (dfVonB$wInf/0.01)^(1/3)
  
  # Adjust time for birth at w = 0:
  tNew <- seq(0,50,by=step)
  VonB <- matrix(0,length(dfVonB$k),length(tNew))
  for (i in 1:length(dfVonB$k)){
    VonB[i,] <- dfVonB$Linf[i]*(1-exp(-dfVonB$k[i]*(tNew-dfVonB$t0[i])))  
    VonB[i,] <- 0.01*VonB[i,]^3/(0.01*dfVonB$Linf[i]^3)
  }
  return(VonB)
}


scales.likelihood <- function (pos.def.matrix = NULL, scales = NULL, xold, use.Ainv = TRUE, 
          d, give_log = TRUE, func = regressor.basis) 
{
  if (is.null(scales) & is.null(pos.def.matrix)) {
    stop("need either scales or a pos.definite.matrix")
  }
  if (!is.null(scales) & !is.null(pos.def.matrix)) {
    stop("scales *and* pos.def.matrix supplied.  corr() needs one only.")
  }
  if (is.null(pos.def.matrix)) {
    pos.def.matrix <- diag(scales, nrow = length(scales))
  }
  H <- regressor.multi(xold, func = func)
  q <- ncol(H)
  n <- nrow(H)
  A <- corr.matrix(xold = xold, pos.def.matrix = pos.def.matrix)
  f <- function(M) {
    (-0.5) * sum(log(eigen(M, TRUE, TRUE)$values))
  }
  bit2 <- f(A)
  if (use.Ainv) {
    Ainv <- chol2inv(chol(A))
    bit1 <- log(sigmahatsquared(H, Ainv, d)) * (-(n - q)/2)
    bit3 <- f(quad.form(Ainv, H))
  }
  else {
    bit1 <- log(sigmahatsquared.A(H, A, d)) * (-(n - q)/2)
    bit3 <- f(quad.form.inv(A, H))
  }
  out <- drop(bit1 + bit2 + bit3)
  if (give_log) {
    return(out)
  }
  else {
    return(exp(out))
  }
}