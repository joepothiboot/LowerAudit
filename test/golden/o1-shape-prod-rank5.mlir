func.func public @case(%arg0: tensor<2x2x2x2x2xf32>) -> tensor<2x2x2x2xf32> {
  %0 = "ttir.prod"(%arg0) <{dim_arg = [4 : i32], keep_dim = false}> : (tensor<2x2x2x2x2xf32>) -> tensor<2x2x2x2xf32>
  return %0 : tensor<2x2x2x2xf32>
}
