using PaddedBlocks
using Documenter

makedocs(;
    modules=[PaddedBlocks],
    authors="Vilim Štih <vilim@neuro.mpg.de>",
    repo="https://github.com/vilim/PaddedBlocks.jl/blob/{commit}{path}#L{line}",
    sitename="PaddedBlocks.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://vilim.github.io/PaddedBlocks.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/vilim/PaddedBlocks.jl",
)
