func.func public @case(%arg0: tensor<7x?x1xsi32>) -> tensor<1x?x1xsi32> {
  %0 = "ttir.prod"(%arg0) <{dim_arg = [-3 : i32, 2 : i32], keep_dim = true}> : (tensor<7x?x1xsi32>) -> tensor<1x?x1xsi32>
  return %0 : tensor<1x?x1xsi32>
}
