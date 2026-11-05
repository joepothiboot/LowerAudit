func.func @probe(%a: tensor<f32>, %b: tensor<f32>, %c: tensor<i1>) -> tensor<f32> {
  %0 = tosa.cond_if %c : tensor<i1> -> tensor<f32> {
    tosa.yield %a : tensor<f32>
  } else {
    tosa.yield %b : tensor<f32>
  }
  return %0 : tensor<f32>
}
