func.func public @case(%arg0: tensor<128x10x4xbf16>) -> tensor<bf16> {
  %0 = "ttir.prod"(%arg0) <{keep_dim = false}> : (tensor<128x10x4xbf16>) -> tensor<bf16>
  return %0 : tensor<bf16>
}
