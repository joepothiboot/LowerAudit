func.func @probe(%a: tensor<i1>) -> tensor<i1> {
  %0 = tosa.while_loop (%b = %a) : (tensor<i1>) -> tensor<i1> {
    tosa.yield %b : tensor<i1>
  } do {
  ^bb0(%b: tensor<i1>):
    tosa.yield %b : tensor<i1>
  }
  return %0 : tensor<i1>
}
