func.func @probe(%a: tensor<?x?xf32>) -> tensor<?x1xf32> {
  %0 = tosa.reduce_sum %a {axis = 1 : i32} : (tensor<?x?xf32>) -> tensor<?x1xf32>
  return %0 : tensor<?x1xf32>
}
