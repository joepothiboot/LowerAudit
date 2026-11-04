func.func public @case(%arg0: tensor<2x2xf32>) -> tensor<2xf32> {
  %0 = "ttir.sum"(%arg0) <{dim_arg = [1 : i32], keep_dim = false}> : (tensor<2x2xf32>) -> tensor<2xf32>
  return %0 : tensor<2xf32>
}
