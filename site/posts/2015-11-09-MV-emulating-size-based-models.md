---
author: Philipp Neubauer
date: '09/11/2015'
output: 'md\_document'
title: 'History matching size-based models 2: a more serious attempt'
...

In a [previous try](2015-05-05-emulation_using_GPs.html), I played with
history matching, a method for fitting complex computer simulation
models to data [@kennedy:2001:bayesian]. My first try (hack?) was a
rather naive attempt to understand how history matching works in
general, and to get an idea of its usefulness for fitting size-spectra
to data. But I didn't really make a serious attempt at going through a
history matching excersize that might produce useful insights into
possible parameter values of uncertain size-spectrum parameters.

So for this try I will make a more serious attempt at fitting
size-spectra, using a simulated trait based model with multivariate
outputs (species bioamss levels, possibly others). I will start with a
very course evaluation of active parameters: those are the parameters
that are considered uncertain and which fundametally alter the dynamics
of the system (those whose variation does not alter the system behaviour
are obviously somewhat redundant).

One thing that did become clear in the first round of history matching
was that univariate emulators are very inefficient. In this post, I will
try more efficient multi-variate emulators that are based on assumption
of separability of input and output variances [@rougier:2008:efficient].
I will also more explicitly query if the emulator makes reasonable
predictions away from data, which is be cruicial if this type of method
is to work for ecosystem models.

Setting up a trait based model
==============================

I will use mizer to set up a trait based model, and estiamte its
(active) parameters. The mizer vignette provides a convenient reminder
how to set this up:

``` {.r}
no_sp = 10
min_w_inf <- 10
max_w_inf <- 1e5
w_inf <- 10^seq(from=log10(min_w_inf), to = log10(max_w_inf), length=10)
knife_edges <- w_inf * 0.05

truth <- set_trait_model(no_sp = no_sp, 
                         r_pp = 10,
                         kappa = 0.01,
                         h=40,
                         beta = 160,
                         sigma= 2,
                         f_0 = 0.8,
                         min_w_inf = min_w_inf, 
                         max_w_inf = max_w_inf,
                         knife_edge_size = knife_edges)
  
sim <- project(truth, t_max = 100, dt=0.2, effort = 0.4)

plot(sim)
```

![](2015-11-09-MV-emulating-size-based-models_files/figure-markdown/simulation-1.png)

Looks like this arbitrary trait based model has converged to a stable
solution. I now use mean biomass (though I could use just the last year)
and total catch over the last 25 years as data for the calibration.

``` {.r}
biom <- colMeans(getBiomass(sim)[75:100,])
catch <- colSums(getYield(sim)[75:100,])
```

Since I want to do a sweep for active parameters first, I take all
parameters that may be considered uncertain in the input dataset. Note
taht this leads to a large hypercube of unknowns, even with a small grid
of possible values across all unknowns. I.e., with 8 unknowns, the grid
with $n=3$ evaluations for each variable is $3^8 \times 8$. Although it
can be efficiently parallelised, the runs required to get this many
outputs take a considerable amount of time. just adding one more point
per parameter would mean pushing the enveloppe (about 1000CPU hours),
any more would be prohibitive. How then to make this tractable? The
answer is to run a small grid (i.e., $n=3$) and then use a fast emulator
to interpolate model outputs and discard those that we believe are
implausible. Here's a start:

``` {.r}
cube_pred <- 4

preds <- data.frame(#seq(2/3,0.9,l=cube_pred),
            #seq(2/3,0.9,l=cube_pred),     
            #seq(0.2,1,l=cube_pred),
            h = seq(3,50,l=cube_pred),
            beta = seq(50,1000,l=cube_pred),
            r_pp = seq(1,100,l=cube_pred),
            kappa = seq(1e-4,1e-2,l=cube_pred),
            sigma = seq(1,3,l=cube_pred))
    
pred_pre_list <- expand.grid(preds)
pred_list <- split(pred_pre_list,1:nrow(pred_pre_list))       

system.time( simdat <- parallel::mclapply(pred_list,
                             function(inputs){
                               this.setup <- set_trait_model(no_sp = no_sp, 
                                                             r_pp = inputs$r_pp,
                                                             kappa = inputs$kappa,
                                                             h=inputs$h,
                                                             beta = inputs$beta,
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
                             },mc.cores = 4))
```

    ##      user    system   elapsed 
    ## 17940.710    37.464  6297.544

``` {.r}
sim_data <- do.call('rbind',simdat)
```

I will keep some of the data here to evaluate the emulator - so I'll
make a training and a test set:

``` {.r}
train <- sample.int(nrow(sim_data), size = 0.9*nrow(sim_data))
test <- which(!(1:nrow(sim_data)) %in% train)

sim_data_train <- sim_data[train,]
sim_data_test <- sim_data[test,]
```

Time to think about how to emulate this model. In geenral, species are
linked and catch is linked to biomass (trivially in this case), so
uni-variate emulation seems like the wrong appraoch. An alternative is
multivariate emulation. In aprticular, the method described in
@rougier:2008:efficient may be appropriate here, since variability for
the outputs is probably similar in output space (although I am not sure
how similar $\Sigma_B$ and $\Sigma_C$ will be with repsect to
variability in the inputs.)

First, source Johnathan Rougiers code:

``` {.r}
source("include/GP_emulators/OPE.R")
```

Next I set up a naive set of regressors that define a Gaussian process
mean, in this case I use a 3rd order polynomial:

``` {.r}
input_reg <- function(inputs) {
  out <- cbind(1,inputs,inputs^2,inputs^3)
  rownames(out) <- sprintf('input %d',1:nrow(as.matrix(inputs)))
  as.matrix(out)
}
```

Next, set up the covariance function in the inputs:

``` {.r}
require(emulator)

input_var <- function(inputs,finputs=NULL) {
  cmat <- corr.matrix(inputs,yold=finputs,scales=10)
  if(!is.null(finputs)) cmat <- t(cmat)
  cmat
}
```

For the method to work, we need to specify regressors on the outputs,
along with a covariance, computed from the points where the simulator is
evaluated (i.e., where we calculate the biomass - at w\_inf for each
species). I use the same as for the inputs here as I have little prior
idea, and the polynomial seems a flexible start. Also, for the output
covariance, I will start with an exponential covariance for simplicity.
Later, I will try to learn the scale parameters of both matrices in
order to optimise the emulator.

``` {.r}
out_grid <- seq(from=log10(min_w_inf), to = log10(max_w_inf), length=10)

output_reg <- function(outputs) {
  out <- cbind(1,outputs,outputs^2,outputs^3)
  rownames(out) <- sprintf('outputs %d',1:nrow(as.matrix(outputs)))
  as.matrix(out)
}

output_regs <- output_reg(out_grid)

output_var <- corr.matrix(as.matrix(out_grid),scales=1)
```

``` {.r}
 vr <- ncol(input_reg(pred_pre_list))
 vs <- ncol(output_regs)
 ms <- rep(0, vr * vs)
 V <- diag(1^2, vr * vs)
   a <- 1
   d <- 1
   NIG <- list(m = ms, V = V, a = a, d = d)
 
 myOPE <- initOPE(gr = input_reg, 
                  kappar = input_var, 
                  Gs = output_regs , 
                  Ws = output_var, 
                  NIG = NIG)

 # stdise is a normal centering and fixing to [-1,1], whereas stdise_wrt(x,y) is with respect to the mean and max of y 
 
m <- as.matrix
stdise <- function(x) apply(x,2,function(y) (y-mean(y))/max(y))
stdise_wrt <- function(x,z) sapply(1:ncol(x), function(y) (x[,y]-mean(z[,y]))/max(z[,y]))
  
ins <- stdise(as.matrix(pred_pre_list[train,]))
ins_test <- stdise_wrt(m(pred_pre_list[test,]),m(pred_pre_list[train,]))

outs <- (sim_data_train-mean(sim_data_train))/max(sim_data_train)
tests <- (sim_data_test-mean(sim_data_train))/max(sim_data_train)

myOPE <- adjustOPE(myOPE, R = ins, Y = outs)

system.time(pp1 <- predictOPE(myOPE, Rp = ins_test, type='EV'))
```

    ##    user  system elapsed 
    ##   0.731   0.088   0.820

For these inputs, it seems as though the emulator does well in
interpolating the results from the size-spectrum for most of the test
set, but some are awefully off:

``` {.r}
quantile(abs((pp1$mu-tests)/tests)*100)
```

    ##           0%          25%          50%          75%         100% 
    ## 9.471410e-04 6.773127e-01 1.934616e+00 5.404830e+00 1.191413e+03

What's this related to?

``` {.r}
# worst prediction
worst <- which.max(rowMeans(abs((pp1$mu-tests)/tests)*100))
# severe under-prediction in the intermediate w_inf trait biomass
((pp1$mu[worst,]-tests[worst,])/tests[worst,])*100
```

    ##            1            2            3            4            5 
    ##    0.3597241  -15.8464317   -2.7385533 1191.4130197  -10.9402668 
    ##            6            7            8            9           10 
    ##    3.6255405   -9.6846286   -1.8168665    0.9253876    0.9589792

``` {.r}
# not really related to the actual test case biomass relative to the training set mean biomass

ins[worst,]
```

    ##          h       beta       r_pp      kappa      sigma 
    ## -0.1578574  0.4700145  0.4919544  0.4951792  0.1088189

``` {.r}
apply(ins,2,quantile)
```

    ##               h       beta       r_pp      kappa      sigma
    ## 0%   -0.4711907 -0.4799855 -0.4980456 -0.4948208 -0.3356255
    ## 25%  -0.4711907 -0.1633189 -0.4980456 -0.4948208 -0.3356255
    ## 50%   0.1554759  0.1533478  0.1619544 -0.1648208  0.1088189
    ## 75%   0.4688093  0.4700145  0.4919544  0.4951792  0.3310411
    ## 100%  0.4688093  0.4700145  0.4919544  0.4951792  0.3310411

Admittedly, I do not quite get where this is coming from - r\_pp and
sigma are high, h is low in the inputs that lead to the poor prediction,
but kappa is low, yet the biomass at the inter-mediate size-level is
under-estimated in the emulator.

References
----------

<br>
