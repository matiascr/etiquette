locals_without_parens = [
  packet: 2,
  packet: 3,
  field: 2,
  field: 3
]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  plugins: [Styler],
  locals_without_parens: locals_without_parens,
  export: [locals_without_parens: locals_without_parens]
]
