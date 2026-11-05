func.func @probe(%a: tensor<2xf32>) -> tensor<2x2x1xf32> {
  %0 = tosa.reduce_sum %a {axis = 0 : i32} : (tensor<2xf32>) -> tensor<2x2x1xf32>
  return %0 : tensor<2x2x1xf32>
}
