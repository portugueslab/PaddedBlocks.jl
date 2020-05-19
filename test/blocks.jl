@testset "Block operations" begin
    n_t = 4
    full_size = (n_t, 4, 8, 1)
    block_size = (n_t, 4, 3, 1)
    padding = (0, 0, 2, 0)
    test_blocks = Blocks(full_size, block_size, (0, 0, 0, 0), (0, 0, 0, 0), padding);

    test_block_starts, test_block_ends = PaddedBlocks.starts_ends(test_blocks);
    @test all(size(test_block_starts) .== (1, 1, 2, 1, 4))
    @test all(test_block_starts[1, 1, 2, 1, :] .== [1, 1, 4, 1])
end
