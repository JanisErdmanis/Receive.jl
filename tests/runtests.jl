using Test
using Receive: receive, Break


@testset "Both channels imidiatelly block at `take!`" begin let

    quit = Channel()
    results = Channel()


    t3 = @async begin
        sleep(0.5)
        for i in 1:10000
            put!(results, i)
        end
    end

    t4 = @async begin 
        sleep(1)
        put!(quit, nothing)
    end


    state = 0
    
    receive(results, quit) do ch, value

        if ch==quit
            close(quit)
            return Break()
        end

        state += 1
    end

    @test state == 10000
    @test istaskdone(t3) == true

end
end

@testset "One channel blocks at `put!` other at `take!`" begin let

    quit = Channel()
    results = Channel()


    t3 = @async begin
        for i in 1:10000
            put!(results, i)
        end
    end

    t4 = @async begin 
        sleep(1)
        put!(quit, nothing)
    end


    #take!(results)
    sleep(0.5)

    state = 0
    
    receive(results, quit) do ch, value

        if ch==quit
            close(quit)
            return Break()
        end

        state += 1

    end
    
    @test state == 10000
    @test istaskdone(t3) == true

end
end


@testset "Interupting while being flooded" begin let

    quit = Channel()
    results = Channel()


    t3 = @async begin
        for i in 1:1000000
            put!(results, i)
        end
    end

    t4 = @async begin 
        sleep(1)
        put!(quit, nothing)
    end


    state = 0
    curvalue = 0
    
    receive(results, quit) do ch, value

        if ch==quit
            close(quit)
            return Break()
        end

        state += 1
        curvalue = value

    end

    @test state == curvalue
    @test state > 10000
    @test istaskdone(t3) == false
    @test take!(results) == state + 1

end
end


@testset "One channel blocks at `take!` frequently and other blocks" begin let

    quit = Channel()
    results = Channel()


    t3 = @async begin
        for i in 1:10
            sleep(0.1)
            put!(results, i)
        end
    end

    t4 = @async begin 
        sleep(0.5)
        put!(quit, nothing)
    end

    state = 0
    
    receive(results, quit) do ch, value

        if ch==quit
            close(quit)
            return Break()
        end

        state = value
    end
    
    @test state > 3
    @test istaskdone(t3) == false
    @test take!(results) == state + 1

end
end
