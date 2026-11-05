func.func @probe(%a: tensor<2x2xf32>) -> tensor<2x1xf32> {
  %0 = tosa.reduce_sum %a {axis = 1 : i32} : (tensor<2x2xf32>) -> tensor<2x1xf32>
  return %0 : tensor<2x1xf32>
}
