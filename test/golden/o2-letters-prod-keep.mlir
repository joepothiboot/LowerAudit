func.func public @case(%arg0: tensor<?x?xf32>) -> tensor<?x1xf32> {
  %0 = "ttir.prod"(%arg0) <{dim_arg = [1 : i32], keep_dim = true}> : (tensor<?x?xf32>) -> tensor<?x1xf32>
  return %0 : tensor<?x1xf32>
}
