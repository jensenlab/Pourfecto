# testing the well connections function that determines which wells are connected to a given aspirate or dispense node 

@testset "Well Connections" begin


    for con in collect(keys(configurations))
        for lw in collect(keys(labwares))




            @testset "Aspirate Well Connections ($con , $lw)" begin 

                l = generate(labwares[lw])

                asp_nodes = compute_flow_nodes(AspNode,[configurations[con]],[l])

                for node in asp_nodes 
                    p = node.piston 
                    connected_channels = sum(node.mask.head.mask[p,:])

                    ch_size = size(channels(head(node.mask)))
                    if typeof(ch_size) == Tuple{Int64} 
                        ch_size = (ch_size[1],1)
                    end 
                    lw_size = JLIMS.shape(l)
                    if (!isa(l,SLASLabware) && !isa(l,brPCR96)) && ch_size != (1,1) && con != "tempest"
                        @test length(well_connections(node)) == 0 
                    else 
                        @test length(well_connections(node)) == connected_channels 
                    end
                end 

            end 
            
            @testset "Dispense Well Connections ($con , $lw)" begin 

                l = generate(labwares[lw])

                disp_nodes = compute_flow_nodes(DispNode,[configurations[con]],[l])

                for node in disp_nodes 
                    p = node.piston 
                    connected_channels = sum(node.mask.head.mask[p,:])
                    ch_size = size(channels(head(node.mask)))
                    if typeof(ch_size) == Tuple{Int64} 
                        ch_size = (ch_size[1],1)
                    end 
                    if con != "cobra"
                        if (!isa(l,SLASLabware) && !isa(l,brPCR96)) && ch_size != (1,1)
                            @test length(well_connections(node)) == 0 
                        else 
                            @test length(well_connections(node)) == connected_channels
                        end
                    else 
                        if (!isa(l,SLASLabware) && !isa(l,brPCR96)) && ch_size != (1,1)
                            @test length(well_connections(node)) == 0 
                        else 
                            @test length(well_connections(node)) <= connected_channels
                        end
                    end

                end 

            end 
        end 
    end 

end