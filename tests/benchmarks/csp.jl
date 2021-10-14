using Receive: Break

struct SelectInterrupt <: Exception end

function waiter(ch::Channel, queue::Channel, ping::Condition)
    try 
        while true
            wait(ch)
            put!(queue, ch)
            wait(ping)
            yield()
        end
    catch err
        if err isa Union{InvalidStateException, SelectInterrupt}
            return nothing
        end
    end
end

function receive_csp(f::Function, ch1::Channel, ch2::Channel)

    queue = Channel{Channel}()

    ping = Condition()

    t1 = @async waiter(ch1, queue, ping)
    t2 = @async waiter(ch2, queue, ping)

    try

        while true
            
            ch = take!(queue) 
            value = take!(ch)
            
            res = f(ch, value) 

            if res isa Break
                break
            end

            notify(ping)
        end

    finally
        close(queue)

        istaskdone(t1) || Base.schedule(t1, SelectInterrupt(), error=true)
        istaskdone(t2) || Base.schedule(t2, SelectInterrupt(), error=true)
    end
end

