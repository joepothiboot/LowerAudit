func.func @probe(%a: tensor<f32>, %b: tensor<f32>) -> tensor<f32> {
  %0 = tosa.add %a, %b : (tensor<f32>, tensor<f32>) -> tensor<f32>
  return %0 : tensor<f32>
}
