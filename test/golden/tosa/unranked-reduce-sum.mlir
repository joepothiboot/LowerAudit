func.func @probe(%a: tensor<*xf32>) -> tensor<*xf32> {
  %0 = tosa.reduce_sum %a {axis = 0 : i32} : (tensor<*xf32>) -> tensor<*xf32>
  return %0 : tensor<*xf32>
}
