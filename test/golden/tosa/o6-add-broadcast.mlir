func.func @probe(%a: tensor<2x1x3xf32>, %b: tensor<1x4x3xf32>) -> tensor<2x4x3xf32> {
  %0 = tosa.add %a, %b : (tensor<2x1x3xf32>, tensor<1x4x3xf32>) -> tensor<2x4x3xf32>
  return %0 : tensor<2x4x3xf32>
}
