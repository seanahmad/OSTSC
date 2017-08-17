#' Generate samples by EPSO and ADASYN.
#' 
#' @param P minority class samples
#' @param N majority class samples
#' @param nTarget The targeted number of samples to achieve
#' @param Per Percentage of the mixing between SPO and ADASYN, with the default value 0.8
#' @param R An scalar ratio to tell in which level (towards the boundary) we shall push our syntactic data, 
#'          with the default value 1
#' @param k k-NN used in the ADASYN algorithm, with the default value 5
#' @param m m-NN used in ADASYN, finding seeds from the Positive Class, with the default value 15
#' @param parallel Whether to run in parallel, with the default setting TRUE (Recommend for dataset with over 30,000 records)
#' @param progBar Whether to include progress bars, with the default setting TRUE
#' @return myData
#' @importFrom stats cov
#' @keywords internal

ReguCovar <- function(P, N, nTarget, R, Per, k, m, parallel, progBar) {
  # Generate samples by EPSO and ADASYN.
  #
  # Args:
  #   P:        minority class samples.
  #   N:        majority class samples. P and N must have the same feature dimention, greater than one,
  #             with no missing values.
  #   nTarget:  The targeted number of samples to achieve.
  #   R:        An scalar ratio to tell in which level (towards the boundary) we shall push our syntactic data,
  #             with the default value 1. 
  #   Per:      Percentage of the mixing between EPSO and ADASYN. 
  #   k:        k-NN used in the ADASYN algorithm, with the default value 5.
  #   m:        m-NN used in ADASYN, finding seeds from the Positive Class, with the default value 15.
  #   parallel: Whether to run in parallel, with the default setting TRUE. (Recommend for dataset with over 30,000 records)
  #   progBar:  Whether to include progress bars, with the default setting TRUE.
  #
  # Returns:
  #   The oversampled dataset myData.
  poscnt <- nrow(P)
  if (nTarget < poscnt) {
    stop ("The targeted positive class size is too small compared with the existing size")
  }
  # Compute Regularized Eigen Spectra
  NumToGen <- ceiling((nTarget - poscnt)*Per)
  NumADASYN <- nTarget - poscnt - NumToGen
  # Me: Mean vector of P
  Me <- apply(P, 2, mean)
  # PCov: vector covariance
  PCov <- cov(P)
  # V:   Eigen axes matrix
  V <- eigen(PCov)$vectors
  # V <- V[, n:1]
  D <- eigen(PCov)$values 
  # d <- D[n:1]
  n <- ncol(P)  # n: The feature dimension
  Ind <- which(D <= 0.005)
  if (length(Ind) != 0) {
    # M: [1,M] the portion of reliable
    M <- Ind[1]
  } else {
    M <- n
  }
  TCov  <- cov(rbind(P, N))
  dT <- crossprod(V, TCov) %*% V
  dT <- diag(dT)
  # Modify the Eigen spectrum according to a 1-Parameter Model
  # dMod: Modified Eigen Spectrum Value
  dMod <- matrix(0, 1, n)
  Alpha <- D[1]*D[M]*(M-1)/(D[1] - D[M])
  Beta  <- (M*D[M] - D[1])/(D[1] - D[M])
  for (i in 1:n) {
    if (i < M) {
      dMod[i] <- D[i]
    } else {
      dMod[i] = Alpha/(i+Beta)
      if (dMod[i] > dT[i]) {
        dMod[i] <- dT[i]
      }
    }
  }
  # Construct Oversampled Data
  if (NumToGen != 0) {
    if (identical(parallel, FALSE)) {
      if (identical(progBar, FALSE)) {
        sample_epso <- EPSO(Me, V, dMod, P, N, R, M, NumToGen)
      } else {
        sample_epso <- EPSOBar(Me, V, dMod, P, N, R, M, NumToGen)
      }
    } else {
      if (identical(progBar, FALSE)) {
        sample_epso <- EPSOPara(Me, V, dMod, P, N, R, M, NumToGen)
      } else {
        sample_epso <- EPSOParaBar(Me, V, dMod, P, N, R, M, NumToGen)
      }
    }
  }

  if (NumADASYN != 0) {
    if (identical(parallel, FALSE)) {
      if (identical(progBar, FALSE)) {
        sample_ada <- ADASYN(t(P), t(N), NumADASYN, k, m)
      } else {
        sample_ada <- ADASYNBar(t(P), t(N), NumADASYN, k, m)
      }
    } else {
      if (identical(progBar, FALSE)) {
        sample_ada <- ADASYNPara(t(P), t(N), NumADASYN, k, m)
      } else {
        sample_ada <- ADASYNParaBar(t(P), t(N), NumADASYN, k, m)
      }
    }
  }
  
  myData <- rbind(t(sample_ada), sample_epso)
  return(myData)
}