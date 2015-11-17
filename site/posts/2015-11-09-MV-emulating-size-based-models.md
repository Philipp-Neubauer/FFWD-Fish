---
author: Philipp Neubauer
date: '09/11/2015'
output: 'md\_document'
title: 'Emulating trait-based models 2: a more serious attempt'
...

Emulating trait-based models 2: a more serious attempt
======================================================

In a [previous try](2015-05-05-emulation_using_GPs.html), I played with
history matching, a method for fitting complex computer simulation
models to data [@kennedy:2001:bayesian]. My first try (hack?) was a
rather naive attempt to understand how history matching works in
general, and to get an idea of its usefulness for fitting size-spectra
to data. But I didn't really make a serious attempt at going through a
history matching exercise that might produce useful insights into
possible parameter values of uncertain size-spectrum parameters.

So for this try I will make a more serious attempt at fitting
size-spectra, using a simulated trait based model with multivariate
outputs (species biomass levels, possibly others). I will start with a
very course evaluation of active parameters: those are the parameters
that are considered uncertain and which fundamentally alter the dynamics
of the system (those whose variation does not alter the system behaviour
are obviously somewhat redundant).

One thing that did become clear in the first round of history matching
was that univariate emulators are very inefficient. In this post, I will
try more efficient multi-variate emulators that are based on assumption
of separability of input and output variances [@rougier:2008:efficient].
I will also more explicitly query if the emulator makes reasonable
predictions away from data, which is be crucial if this type of method
is to work for ecosystem models.

Setting up a trait based model
------------------------------

I will use mizer to set up a trait based model, and estimate its
(active) parameters. The mizer vignette provides a convenient reminder
how to set this up:

``` {.r}
no_sp = 10
min_w_inf <- 10
max_w_inf <- 1e5
w_inf <- 10^seq(from=log10(min_w_inf), to = log10(max_w_inf), length=10)
knife_edges <- w_inf * 0.05

truth <- set_trait_model(no_sp = no_sp, 
                         h=40,
                         kappa = 0.01,
                         r_pp = 10,
                         beta = 300,
                         sigma= 1.3,
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

Building an emulator
--------------------

Since I want to do a sweep for active parameters first, I take all
parameters that may be considered uncertain in the input dataset. Note
that this leads to a large hyper-cube of unknowns, even with a small
grid of possible values across all unknowns. I.e., with 8 unknowns, the
grid with $n=3$ evaluations for each variable is $3^8 \times 8$.
Although it can be efficiently parallelised, the runs required to get
this many outputs take a considerable amount of time. just adding one
more point per parameter would mean pushing the envelope (about 1000CPU
hours), any more would be prohibitive. How then to make this tractable?
The answer is to run a small grid (i.e., $n=3$) and then use a fast
emulator to interpolate model outputs and discard those that we believe
are implausible. Here's a start:

``` {.r}
cube_pred <- 8
lseq <- function(mins,maxs,l) 10^(seq(log10(mins),log10(maxs),l=l))

preds <- data.frame(#seq(2/3,0.9,l=cube_pred),
            #seq(2/3,0.9,l=cube_pred),     
            #seq(0.2,1,l=cube_pred),
            h = seq(3,150,l=cube_pred),
            #beta = seq(50,1000,l=cube_pred)#,
            r_pp = lseq(0.005,100,l=cube_pred),
            #kappa = seq(1e-3,1e-1,l=cube_pred),
            sigma = seq(0.5,4,l=cube_pred)
            )
    
pred_pre_list <- expand.grid(preds)
pred_pre_list_jitter <- jitter_preds(preds)
pred_list <- split(data.frame(pred_pre_list_jitter),1:nrow(pred_pre_list))       
system.time( simdat <- parallel::mclapply(pred_list,
                                          run_SS_sim,
                                          mc.cores = 6))
```

    ##     user   system  elapsed 
    ## 7459.018   31.001 1535.538

``` {.r}
sim_data <- do.call('rbind',simdat)
```

I will keep some of the data here to evaluate the emulator - so I'll
make a training and a test set:

``` {.r}
#naset <- which(apply(sim_data,1,function(x) any(is.na(x))))
#sim_data <- sim_data[-naset,]

pred_pre_list_df <- data.frame(pred_pre_list_jitter)

pred_pre_list_df$p_reg  <- apply(sim_data,1,function(pred){
  t(biom - pred) %*% 
    diag(1/(0.5*(diag(var(sim_data))))) %*% 
    (biom - pred)
})>3

mpreds <- reshape2::melt(pred_pre_list_df)
```

    ## Using p_reg as id variables

``` {.r}
ggplot(mpreds) + 
  facet_grid( p_reg ~ variable,scales = "free") + 
  geom_bar(aes(x=value)) + 
  theme_bw() + 
  xlab('Parameter')
```

    ## stat_bin: binwidth defaulted to range/30. Use 'binwidth = x' to adjust this.
    ## stat_bin: binwidth defaulted to range/30. Use 'binwidth = x' to adjust this.
    ## stat_bin: binwidth defaulted to range/30. Use 'binwidth = x' to adjust this.
    ## stat_bin: binwidth defaulted to range/30. Use 'binwidth = x' to adjust this.
    ## stat_bin: binwidth defaulted to range/30. Use 'binwidth = x' to adjust this.
    ## stat_bin: binwidth defaulted to range/30. Use 'binwidth = x' to adjust this.

![](2015-11-09-MV-emulating-size-based-models_files/figure-markdown/check%20first%20outputs,%20Wave%200%20of%20checking%20for%20predictions%20that%20are%20wayy%20off-1.png)

``` {.r}
keep <- mpreds %>%
  filter(p_reg ==F) %>%
  group_by(variable) %>%
  summarise(q1 = min(value),
            q3 = max(value)) %>%
  data.frame()

cube_pred <- 12
new_preds <- data.frame(#seq(2/3,0.9,l=cube_pred),
            #seq(2/3,0.9,l=cube_pred),     
            #seq(0.2,1,l=cube_pred),
            h = seq(keep[1,2],keep[1,3],l=cube_pred),
            #beta = seq(50,1000,l=cube_pred)#,
            r_pp = lseq(keep[2,2],keep[2,3],l=cube_pred),
            #kappa = seq(1e-3,1e-1,l=cube_pred),
            sigma = seq(keep[3,2],keep[3,3],l=cube_pred)
            )
    
new_pred_pre_list_jitter <- jitter_preds(new_preds,keep)

mp <- reshape2::melt(new_pred_pre_list_jitter)
ggplot(mp,aes(x=value)) + 
  geom_histogram(aes(x=value)) + 
  facet_wrap(~Var2,scales='free') + 
  theme_bw()+ 
  xlab('Parameter')
```

    ## stat_bin: binwidth defaulted to range/30. Use 'binwidth = x' to adjust this.
    ## stat_bin: binwidth defaulted to range/30. Use 'binwidth = x' to adjust this.
    ## stat_bin: binwidth defaulted to range/30. Use 'binwidth = x' to adjust this.

![](2015-11-09-MV-emulating-size-based-models_files/figure-markdown/update%20training%20set-1.png)

``` {.r}
new_pred_list <- split(data.frame(new_pred_pre_list_jitter),
                       1:nrow(new_pred_pre_list_jitter))   

system.time( new_simdat <- parallel::mclapply(new_pred_list,
                                              run_SS_sim,
                                              mc.cores = 6))
```

    ##      user    system   elapsed 
    ## 30526.823   133.624  6253.170

``` {.r}
new_sim_data <- do.call('rbind',new_simdat)

pred_pre_list_df <- data.frame(new_pred_pre_list_jitter)
pred_pre_list_df$p_reg <- apply(new_sim_data,1,function(x) any(x<(min(biom)/1000)))

mpreds <- reshape2::melt(pred_pre_list_df)
```

    ## Using p_reg as id variables

``` {.r}
ggplot(mpreds) + 
  facet_grid( p_reg ~ variable,scales = "free") + 
  geom_bar(aes(x=value)) + 
  theme_bw() + 
  xlab('Parameter')
```

    ## stat_bin: binwidth defaulted to range/30. Use 'binwidth = x' to adjust this.
    ## stat_bin: binwidth defaulted to range/30. Use 'binwidth = x' to adjust this.
    ## stat_bin: binwidth defaulted to range/30. Use 'binwidth = x' to adjust this.
    ## stat_bin: binwidth defaulted to range/30. Use 'binwidth = x' to adjust this.
    ## stat_bin: binwidth defaulted to range/30. Use 'binwidth = x' to adjust this.
    ## stat_bin: binwidth defaulted to range/30. Use 'binwidth = x' to adjust this.

![](2015-11-09-MV-emulating-size-based-models_files/figure-markdown/run%20training%20set-1.png)

``` {.r}
keep <- mpreds %>%
  filter(p_reg ==F) %>%
  group_by(variable) %>%
  summarise(q1 = min(value),
            q3 = max(value)) %>%
  data.frame()

keepers <- !pred_pre_list_df$p_reg#apply(pred_pre_list_df, 1, function(x) x[1] >= keep[1,2] & x[1] <= keep[1,3] & x[2] >= keep[2,2] & x[2] <= keep[2,3] & x[3] >= keep[3,2] & x[3] <= keep[3,3])

sim_data <- new_sim_data[keepers,]

train <- sample.int(nrow(sim_data), size = 0.9*nrow(sim_data))
test <- which(!(1:nrow(sim_data)) %in% train)

sim_data_train <- sim_data[train,]
sim_data_test <- sim_data[test,]
```

Time to think about how to emulate this model. In general, species are
linked and catch is linked to biomass (trivially in this case), so
uni-variate emulation seems like the wrong approach. An alternative is
multivariate emulation. In particular, the method described in
@rougier:2008:efficient may be appropriate here, since variability for
the outputs is probably similar in output space (although I am not sure
how similar $\Sigma_B$ and $\Sigma_C$ will be with respect to
variability in the inputs.)

First, source Johnathan Rougiers code:

``` {.r}
source("include/GP_emulators/OPE.R")
```

For the method to work, we need to specify regressors on the outputs,
along with a covariance, computed from the points where the simulator is
evaluated (i.e., where we calculate the biomass - at w\_inf for each
species). I use the same as for the inputs here as I have little prior
idea, and the polynomial seems a flexible start. Also, for the output
covariance, I will start with an exponential covariance for simplicity.
Later, I will try to learn the scale parameters of both matrices in
order to optimise the emulator.

I can now define a GP emulator:

``` {.r}
 # stdise is a normal centering and fixing to [-1,1], whereas stdise_wrt(x,y) is with respect to the mean and max of y 

pred_pre_list <- new_pred_pre_list_jitter[keepers,]
ins <- stdise(as.matrix(pred_pre_list[train,]))
ins_test <- stdise_wrt(m(pred_pre_list[test,]),m(pred_pre_list[train,]))

outs <- stdise(log(sim_data_train))
tests <- stdise_wrt(log(sim_data_test),log(sim_data_train))

scales <- 1/(0.125*as.vector(diff(apply(ins,2,range))))^2
out_grid <- (seq(from=log10(min_w_inf), to = log10(max_w_inf), length=10))
out_grid <- (out_grid-mean(out_grid))/sd(out_grid)

OPE <- define_OPE(c(2,(scales)),
                  inData = ins,
                  outGrid = out_grid,
                  outData = outs)
 
cuts <- cut(1:nrow(ins_test),nrow(ins_test)/10)
ins_test_sp <- split(data.frame(ins_test), cuts)

test_pred <- mclapply(ins_test_sp, 
                      function(ins) emulate(ins,
                                            OPE,
                                            split=F,
                                            rev_std_out=T,
                                            rev_std_data = log(sim_data_train)),
                      mc.cores = 8)

test_pred <- do.call('rbind',test_pred)
```

### How well does the emulator perform?

For these inputs, it seems as though the emulator does well in
interpolating the results from the size-spectrum for most of the test
set:

``` {.r}
plot(exp(test_pred$mu),as.vector(t(sim_data_test)))
abline(a=0,b=1)
```

![](2015-11-09-MV-emulating-size-based-models_files/figure-markdown/testing-1.png)

``` {.r}
summary(lm(exp(test_pred$mu)~0+as.vector(t(sim_data_test))))
```

    ## 
    ## Call:
    ## lm(formula = exp(test_pred$mu) ~ 0 + as.vector(t(sim_data_test)))
    ## 
    ## Residuals:
    ##        Min         1Q     Median         3Q        Max 
    ## -0.0304110 -0.0017602 -0.0000991  0.0014776  0.0250091 
    ## 
    ## Coefficients:
    ##                             Estimate Std. Error t value Pr(>|t|)    
    ## as.vector(t(sim_data_test)) 0.932824   0.005451   171.1   <2e-16 ***
    ## ---
    ## Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
    ## 
    ## Residual standard error: 0.004156 on 1359 degrees of freedom
    ## Multiple R-squared:  0.9557, Adjusted R-squared:  0.9556 
    ## F-statistic: 2.928e+04 on 1 and 1359 DF,  p-value: < 2.2e-16

### Improving the emulator

It might be possible to get better prediction by adjusting the length
scale of the GP covariances. For this, I use a function to optimise the
length scales based on the GP marginal likelihoods, and then define the
new emulator by those length scales:

``` {.r}
sset <- sample.int(nrow(pred_pre_list),1e3)

opt_OPE <- optim(c(1,(scales)),
      define_OPE,
      inData = stdise(as.matrix(pred_pre_list[sset,])),
      outGrid = out_grid,
      outData = stdise(log(sim_data[sset,])),
      opt=T,
      control = list(fnscale=-1,
                     trace = 100,
                     reltol = 1e-6))
```

    ##   Nelder-Mead direct search function minimizer
    ## function value for initial parameters = 44720.244513
    ##   Scaled convergence tolerance is 0.0447202
    ## Stepsize computed as 0.630749
    ## BUILD              5 44720.244513 38587.010409
    ## LO-REDUCTION       7 44676.390765 38587.010409
    ## LO-REDUCTION       9 44425.405271 38587.010409
    ## EXTENSION         11 44015.680076 37467.371338
    ## LO-REDUCTION      13 40190.096830 37467.371338
    ## LO-REDUCTION      15 38953.925371 37467.371338
    ## LO-REDUCTION      17 38587.010409 37467.371338
    ## LO-REDUCTION      19 37638.744537 37467.371338
    ## HI-REDUCTION      21 37629.318596 37467.371338
    ## EXTENSION         23 37577.060418 37387.709619
    ## LO-REDUCTION      25 37544.136092 37387.709619
    ## HI-REDUCTION      27 37542.608367 37387.709619
    ## EXTENSION         29 37467.371338 37314.406850
    ## EXTENSION         31 37455.560278 37274.127626
    ## LO-REDUCTION      33 37416.268922 37274.127626
    ## REFLECTION        35 37387.709619 37254.479075
    ## REFLECTION        37 37314.406850 37232.947566
    ## LO-REDUCTION      39 37290.712762 37232.947566
    ## REFLECTION        41 37274.127626 37213.021954
    ## HI-REDUCTION      43 37258.492233 37213.021954
    ## REFLECTION        45 37254.479075 37200.053445
    ## LO-REDUCTION      47 37234.206169 37200.053445
    ## HI-REDUCTION      49 37232.947566 37200.053445
    ## LO-REDUCTION      51 37213.021954 37200.053445
    ## LO-REDUCTION      53 37211.665859 37199.050352
    ## REFLECTION        55 37202.072187 37192.215244
    ## EXTENSION         57 37201.125615 37187.682252
    ## HI-REDUCTION      59 37200.053445 37187.682252
    ## EXTENSION         61 37199.050352 37185.515904
    ## EXTENSION         63 37194.263633 37174.507701
    ## EXTENSION         65 37192.215244 37159.699951
    ## LO-REDUCTION      67 37187.682252 37159.699951
    ## LO-REDUCTION      69 37185.515904 37159.699951
    ## REFLECTION        71 37174.507701 37158.942596
    ## EXTENSION         73 37171.188392 37147.360264
    ## LO-REDUCTION      75 37169.645922 37147.360264
    ## EXTENSION         77 37159.699951 37141.508317
    ## LO-REDUCTION      79 37158.942596 37141.508317
    ## REFLECTION        81 37151.609838 37138.947944
    ## REFLECTION        83 37147.360264 37135.285063
    ## HI-REDUCTION      85 37142.250014 37135.285063
    ## LO-REDUCTION      87 37141.508317 37135.285063
    ## LO-REDUCTION      89 37139.257098 37135.285063
    ## LO-REDUCTION      91 37138.947944 37135.285063
    ## REFLECTION        93 37136.731250 37135.095055
    ## LO-REDUCTION      95 37136.703957 37135.095055
    ## REFLECTION        97 37136.101100 37134.873549
    ## HI-REDUCTION      99 37135.285063 37134.873549
    ## LO-REDUCTION     101 37135.130531 37134.741045
    ## LO-REDUCTION     103 37135.095055 37134.615543
    ## HI-REDUCTION     105 37134.970978 37134.615543
    ## HI-REDUCTION     107 37134.873549 37134.615543
    ## HI-REDUCTION     109 37134.741045 37134.615543
    ## LO-REDUCTION     111 37134.687956 37134.614946
    ## HI-REDUCTION     113 37134.675851 37134.612970
    ## HI-REDUCTION     115 37134.662867 37134.612970
    ## Exiting from Nelder Mead minimizer
    ##     117 function evaluations used

The new emulator with optimised GP length scales is now:

``` {.r}
OPE_opt <- define_OPE(opt_OPE$par,
                      inData = stdise(as.matrix(pred_pre_list)),
                      outGrid = out_grid,
                      outData = stdise(log(sim_data)))

OPE_opt_test <- adjustOPE(OPE_opt, R = ins, Y = outs)


test_pred <- mclapply(ins_test_sp, 
                      function(ins) emulate(ins,
                                            OPE_opt_test,
                                            split=F,
                                            rev_std_out=T,
                                            rev_std_data = log(sim_data_train)),
                      mc.cores = 8)

test_pred <- do.call('rbind',test_pred)

plot(exp(test_pred$mu),as.vector(t(sim_data_test)))
abline(a=0,b=1)
```

![](2015-11-09-MV-emulating-size-based-models_files/figure-markdown/test%20refined%20OPE-1.png)

``` {.r}
summary(lm(exp(test_pred$mu)~0+as.vector(t(sim_data_test))))
```

    ## 
    ## Call:
    ## lm(formula = exp(test_pred$mu) ~ 0 + as.vector(t(sim_data_test)))
    ## 
    ## Residuals:
    ##       Min        1Q    Median        3Q       Max 
    ## -0.030522 -0.001956 -0.000121  0.001564  0.026330 
    ## 
    ## Coefficients:
    ##                             Estimate Std. Error t value Pr(>|t|)    
    ## as.vector(t(sim_data_test)) 0.929755   0.005655   164.4   <2e-16 ***
    ## ---
    ## Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
    ## 
    ## Residual standard error: 0.004312 on 1359 degrees of freedom
    ## Multiple R-squared:  0.9521, Adjusted R-squared:  0.9521 
    ## F-statistic: 2.703e+04 on 1 and 1359 DF,  p-value: < 2.2e-16

Indeed, now 75% of predictions are within
`quantile(abs((exp(test_pred$mu)-as.vector(t(sim_data_test)))/as.vector(t(sim_data_test)))*100)[4]`%
of the simulations. Much better! Some vindication that I am (perhaps) on
the right track.

Can the emulator emulate the size-spectrum response?
----------------------------------------------------

To test the emulator, its worthwhile testing how well the emulator
predicts the responses to changes in the inputs:

``` {.r}
pred_size <- 20

testset1 <- data.frame(h=seq(35,66,l=pred_size),
                       r_pp = 10,
                       sigma= 1.3)

test_em(testset1, 
        OPE_opt, 
        'h')
```

    ## Joining by: c("h", "Species")

![](2015-11-09-MV-emulating-size-based-models_files/figure-markdown/test%20opt_OPT%20response-1.png)

``` {.r}
testset2 <- data.frame(h=40,
                       r_pp = 10,
                       sigma= seq(1.7,3.5,l=pred_size))

test_em(testset2, 
        OPE_opt, 
        'sigma')
```

    ## Joining by: c("sigma", "Species")

![](2015-11-09-MV-emulating-size-based-models_files/figure-markdown/test%20opt_OPT%20response-2.png)

``` {.r}
testset3 <- data.frame(h=40,
                       r_pp = lseq(1,10,l=pred_size),
                       sigma= 1.3)

test_em(testset3, 
        OPE_opt, 
        'r_pp')
```

    ## Joining by: c("r_pp", "Species")

![](2015-11-09-MV-emulating-size-based-models_files/figure-markdown/test%20opt_OPT%20response-3.png)

``` {.r}
testset11 <- data.frame(h=seq(35,66,l=pred_size),
                       r_pp = 1,
                       sigma= 2.5)

test_em(testset11, 
        OPE_opt, 
        'h')
```

    ## Joining by: c("h", "Species")

![](2015-11-09-MV-emulating-size-based-models_files/figure-markdown/test%20opt_OPT%20response2-1.png)

``` {.r}
testset22 <- data.frame(h=60,
                       r_pp = 1,
                       sigma= seq(1.7,3.5,l=pred_size))

test_em(testset22, 
        OPE_opt, 
        'sigma')
```

    ## Joining by: c("sigma", "Species")

![](2015-11-09-MV-emulating-size-based-models_files/figure-markdown/test%20opt_OPT%20response2-2.png)

``` {.r}
testset33 <- data.frame(h=60,
                       r_pp = lseq(1,10,l=pred_size),
                       sigma= 2.5)

test_em(testset33, 
        OPE_opt, 
        'r_pp')
```

    ## Joining by: c("r_pp", "Species")

![](2015-11-09-MV-emulating-size-based-models_files/figure-markdown/test%20opt_OPT%20response2-3.png)

References
----------

<br>
