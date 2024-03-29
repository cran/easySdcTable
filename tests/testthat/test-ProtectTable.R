library(RegSDC)
library(Matrix)

PTxyzTest = function(..., rmse = pi/3, nRep = 2){
  a <- PTxyz(..., IncProgress=NULL)
  s <- Matrix::crossprod(a$x,SuppressDec(a$x, a$z, a$y, rmse = rmse, nRep = nRep))[which(is.na(a$z)), ,drop=FALSE]
  rowSumsDes <- Matrix::rowSums(RoundWhole(s))
  rowSumsRoundDes <- Matrix::rowSums(round(s))
  expect_false(any(rowSumsDes==rowSumsRoundDes))
}


# Data for testing threshold and detectSingletons
z <- data.frame(a = rep(1:5, each = 7), b = 1:7, y = 4:10, y0 = 4:10, y1 = 4:10)
z$y0[(z$y + 1.7 * z$a) > 12] <- 0
z$y1[(z$y + 1.6 * z$a) > 9.7] <- 1  # 9


test_that("Simple works", {
  PTxyzTest(EasyData("z1"), c("region","hovedint") ,"ant", method = "Simple")
  # PTxyzTest(EasyData("z3") ,1:6,7, method = "SIMPLEHEURISTIC") # linked tables, fails
  PTxyzTest(z, 1:2,"y0", protectZeros = TRUE,  method = "Simple")
  PTxyzTest(z, 1:2,"y1", protectZeros = FALSE,  method = "Simple")
})

test_that("SimpleSingle works", {
  PTxyzTest(z, 1:2, "y0", protectZeros = TRUE, method = "SimpleSingle")
  w <- ProtectTable(z, 1:2, "y0", protectZeros = TRUE, IncProgress = NULL, method = "SimpleSingle")$data
  expect_true(sum(w[w$b == 3 & is.na(w$suppressed), "freq", drop = TRUE]) > 0)
  
  PTxyzTest(z, 1:2, "y1", protectZeros = FALSE, method = "SimpleSingle")
  w <- ProtectTable(z, 1:2, "y1", protectZeros = FALSE, IncProgress = NULL, method = "SimpleSingle")$data
  expect_true(sum(w[w$b == 1 & is.na(w$suppressed), "freq", drop = TRUE] - 1) > 0)
})

test_that("SIMPLEHEURISTICSingle works", {
  PTxyzTest(z, 1:2, "y0", protectZeros = TRUE, method = "SIMPLEHEURISTICSingle")
  w <- ProtectTable(z, 1:2, "y0", protectZeros = TRUE, IncProgress = NULL, method = "SIMPLEHEURISTICSingle")$data
  expect_true(sum(w[w$b == 3 & is.na(w$suppressed), "freq", drop = TRUE]) > 0)
  
  PTxyzTest(z, 1:2, "y1", protectZeros = FALSE, method = "SIMPLEHEURISTICSingle")
  w <- ProtectTable(z, 1:2, "y1", protectZeros = FALSE, IncProgress = NULL, method = "SIMPLEHEURISTICSingle")$data
  expect_true(sum(w[w$b == 1 & is.na(w$suppressed), "freq", drop = TRUE] - 1) > 0)
})


test_that("Gauss works", {
  PTxyzTest(EasyData("z1"), c("region","hovedint") ,"ant", method = "Gauss", printInc=FALSE)
  PTxyzTest(EasyData("z3") ,1:6,7, method = "Gauss", printInc=FALSE) 
  PTxyzTest(z, 1:2, "y0", protectZeros = TRUE, method = "Gauss", printInc=FALSE)
  w <- ProtectTable(z, 1:2, "y0", protectZeros = TRUE, method = "Gauss", IncProgress = NULL, printInc=FALSE)$data
  expect_true(sum(w[w$b == 3 & is.na(w$suppressed), "freq", drop = TRUE]) > 0)
  PTxyzTest(z, 1:2, "y1", protectZeros = FALSE, method = "Gauss", printInc=FALSE)
  w <- ProtectTable(z, 1:2, "y1", protectZeros = FALSE, method = "Gauss", IncProgress = NULL, printInc=FALSE)$data
  expect_true(sum(w[w$b == 1 & is.na(w$suppressed), "freq", drop = TRUE] - 1) > 0)
})


test_that("Empty input protected", {
  z1_ <- EasyData("z1")
  z1_$ant[1] <- 0
  a <- ProtectTableData(z1_, 1:2, 3, IncProgress = NULL,  printInc=FALSE)
  b <- ProtectTableData(z1_[-1, ], 1:2, 3, IncProgress = NULL,  printInc=FALSE)
  a <- SSBtools::SortRows(a)
  b <- SSBtools::SortRows(b)
  expect_identical(a$sdcStatus, b$sdcStatus)
})



Gauss6 <- function(...) {
  m <- NULL
  singletonMethod <- c("none", "subSum", "anySum", "subSumAny", "subSpace", "subSumSpace")
  for (i in seq_along(singletonMethod)) {
    a <- ProtectTable(..., method = "Gauss", singletonMethod = singletonMethod[i], IncProgress = NULL, printInc = FALSE)
    m <- cbind(m, a$data$suppressed)
  }
  colnames(m) <- singletonMethod
  expect_identical(m[, "anySum"], m[, "subSumAny"])
  expect_identical(m[, "subSpace"], m[, "subSumSpace"])
  k <- apply(m, 2, sumIsNa)[c(1, 2, 3, 5)]
  expect_true(min(diff(k)) > 0)
  m
}

sumIsNa <- function(x) sum(is.na(x))

test_that("Gauss ok singleton methods", {
  m0 <- Gauss6(z, 1:2, "y0")
  m1 <- Gauss6(z, 1:2, "y1", protectZeros = FALSE)
})


test_that("When micro data combined with Gauss", {
  z2 <- EasyData("z2")
  z2[z2$ant > 16, "ant"] <- 0
  z2 <- z2[z2$ant != 0, ]
  z2[z2$ant > 10, "ant"] <- 1
  z2micro <- SSBtools::MakeMicro(z2, "ant")
  a <- ProtectTableData(z2, c("kostragr", "hovedint", "region", "fylke"), "ant", protectZeros = FALSE, IncProgress = NULL, printInc = FALSE)
  b <- ProtectTableData(z2micro, c("kostragr", "hovedint", "region", "fylke"), protectZeros = FALSE, IncProgress = NULL, printInc = FALSE)
  expect_identical(a, b)
  a <- ProtectTableData(z2, c("kostragr", "hovedint", "region", "fylke"), "ant", protectZeros = TRUE, IncProgress = NULL, printInc = FALSE)
  b <- ProtectTableData(z2micro, c("kostragr", "hovedint", "region", "fylke"), protectZeros = TRUE, IncProgress = NULL, printInc = FALSE)
  expect_identical(a, b)
})

