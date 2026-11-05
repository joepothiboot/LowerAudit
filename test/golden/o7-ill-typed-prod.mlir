func.func public @case(%arg0: tensor<2xf32>) -> tensor<2x2x1xf32> {
  %0 = "ttir.prod"(%arg0) <{dim_arg = [0 : i32], keep_dim = false}> : (tensor<2xf32>) -> tensor<2x2x1xf32>
  return %0 : tensor<2x2x1xf32>
}
