# Enforce the important TypeSafeSDK dependency directions. Generated modules and
# data-only response structs intentionally remain outside these layers; this gate
# protects handwritten semantic/runtime boundaries rather than generated shape.
[
  checks: [source_paths: ["lib", "codegen"]],
  layers: [
    semantic: [
      "TypeSafeSDK.Question",
      "TypeSafeSDK.Question.Validation",
      "TypeSafeSDK.Question.Noul",
      "TypeSafeSDK.Question.Choice",
      "TypeSafeSDK.Question.Score",
      "TypeSafeSDK.Prepared",
      "TypeSafeSDK.Answer",
      "TypeSafeSDK.Answer.Noul",
      "TypeSafeSDK.Answer.Choice",
      "TypeSafeSDK.Answer.Score",
      "TypeSafeSDK.Response",
      "TypeSafeSDK.RequestBudget",
      "TypeSafeSDK.ResponseContract",
      "TypeSafeSDK.SemanticResponse"
    ],
    orchestration: [
      "TypeSafeSDK.Evaluation",
      "TypeSafeSDK.Batch",
      "TypeSafeSDK.Batch.Lifecycle",
      "TypeSafeSDK.OTP.Server",
      "TypeSafeSDK.Telemetry"
    ],
    runtime: [
      "TypeSafeSDK.Client",
      "TypeSafeSDK.SystemOne",
      "TypeSafeSDK.RuntimeCapabilities",
      "TypeSafeSDK.ProviderProfile",
      "TypeSafeSDK.ResultClassifier",
      "TypeSafeSDK.TransportResponse",
      "TypeSafeSDK.TransportError"
    ]
  ],
  deps: [
    forbidden: [
      {:semantic, :orchestration},
      {:semantic, :runtime},
      {:runtime, :orchestration}
    ]
  ]
]
