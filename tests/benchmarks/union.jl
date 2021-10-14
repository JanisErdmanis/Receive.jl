# Comparison to a situation when all values are being put in one
# channel. Note in such situation we will have only one receiving
# channel. This example also shows a starvation issue as consumer gets
# `nothing` only after all numbers are consumed.

consumer = Channel()

t3 = @async begin
    for i in 1:1000000
        put!(consumer, i)
    end
end

t4 = @async begin 
    sleep(1)
    put!(consumer, nothing)
end


let
    state = 0

    start = time()

    while true

        value = take!(consumer)

        if value == nothing
            break
        end

        state = value
        
    end

    duration = time() - start

    @show duration, state

end
