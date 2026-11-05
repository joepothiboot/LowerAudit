func.func @probe(%a: tensor<4xf32>, %x: i32, %m: i32, %s: i8) -> (tensor<f32>, tensor<2x2xf32>, tensor<8xf32>, tensor<2xf32>, tensor<6xf32>, i32) {
  %const = "tosa.const"() {values = dense<1.0> : tensor<f32>} : () -> tensor<f32>
  %shape = tosa.const_shape {values = dense<[2, 2]> : tensor<2xindex>} : () -> !tosa.shape<2>
  %reshape = tosa.reshape %a, %shape : (tensor<4xf32>, !tosa.shape<2>) -> tensor<2x2xf32>
  %concat = tosa.concat %a, %a {axis = 0 : i32} : (tensor<4xf32>, tensor<4xf32>) -> tensor<8xf32>
  %start = tosa.const_shape {values = dense<[0]> : tensor<1xindex>} : () -> !tosa.shape<1>
  %size = tosa.const_shape {values = dense<[2]> : tensor<1xindex>} : () -> !tosa.shape<1>
  %slice = tosa.slice %a, %start, %size : (tensor<4xf32>, !tosa.shape<1>, !tosa.shape<1>) -> tensor<2xf32>
  %padding = tosa.const_shape {values = dense<[1, 1]> : tensor<2xindex>} : () -> !tosa.shape<2>
  %fill = "tosa.const"() {values = dense<0.0> : tensor<1xf32>} : () -> tensor<1xf32>
  %pad = tosa.pad %a, %padding, %fill : (tensor<4xf32>, !tosa.shape<2>, tensor<1xf32>) -> tensor<6xf32>
  %scaled = tosa.apply_scale %x, %m, %s {rounding_mode = SINGLE_ROUND} : (i32, i32, i8) -> i32
  return %const, %reshape, %concat, %slice, %pad, %scaled : tensor<f32>, tensor<2x2xf32>, tensor<8xf32>, tensor<2xf32>, tensor<6xf32>, i32
}
