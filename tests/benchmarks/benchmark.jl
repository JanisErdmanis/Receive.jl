using Receive: Break, receive
using Select

include("select.jl")
include("csp.jl")

cases = [
("Select.jl", receive_select), 
("CSP", receive_csp),
("Receive.jl", receive)
]

for (str, receive) in cases

    state = let
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
        
        # Select.jl has starvation issue if instead
        # `receive_select(results, quit)` is used!
        receive(quit, results) do ch, value

            if ch==quit
                close(quit)
                return Break()
            end

            state += 1
            curvalue = value

        end
        
        @assert state == curvalue
        state
    end

    println("$str: $state")
end
