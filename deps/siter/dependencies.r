deps <- c('knitr', 'rmarkdown', 'devtools', 'dplyr', 'ggplot2','INLA','rjags','mizer')
inst_deps <- sapply(deps, function(o) {
    if(!require(o, character.only=T)) {
        install.packages(o, repos='http://cran.stat.auckland.ac.nz/')
    }
})

