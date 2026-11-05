func.func @probe(%a: tensor<1x50x48x1xf32>) -> tensor<1x1600x1536x1xf32> {
  %scale = tosa.const_shape {values = dense<[64, 2, 64, 2]> : tensor<4xindex>} : () -> !tosa.shape<4>
  %offset = tosa.const_shape {values = dense<[-31, -31]> : tensor<2xindex>} : () -> !tosa.shape<2>
  %border = tosa.const_shape {values = dense<[31, 31]> : tensor<2xindex>} : () -> !tosa.shape<2>
  %0 = tosa.resize %a, %scale, %offset, %border {mode = NEAREST_NEIGHBOR} : (tensor<1x50x48x1xf32>, !tosa.shape<4>, !tosa.shape<2>, !tosa.shape<2>) -> tensor<1x1600x1536x1xf32>
  return %0 : tensor<1x1600x1536x1xf32>
}
