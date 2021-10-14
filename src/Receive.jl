module Receive

include("patch.jl")

struct Break end

haslock(ch::Channel) = current_task() == ch.cond_put.lock.locked_by
isflushed(ch::Channel) = haslock(ch) && !isready(ch)


"""
    _receive_nonblocking(f::Function, ch_vec::Vector{Channel})

Acquires lock for each channel in nonblocking way with `trylock` and
for each unsuccessful attempt takes value from the channel. When lock
is acquired channel is flushed until `isready(ch)==false`. To prevent
starvation the order of channels are permuted like 123 231 312 for
three channels.
"""
function _receive_nonblocking(f::Function, ch_vec::Vector{Channel})

    N = length(ch_vec)

    k = 1
    j = 1

    terminated = false
    bingo = false 

    while true

        if k == j
            j = mod(j, N) + 1
            k = j
        
            bingo==true && break
            bingo = true
        end

        k = mod(k, N) + 1

        ch = ch_vec[k]

        # If lock is not owned this part shall be executed only if
        # either lock can not be acquired. If lock is acquired then I
        # need to check whether there are available values which I can
        # take.

        #if (!(haslock(ch) || trylock(ch)) && isready(ch) ) || (haslock(ch) && isready(ch))

        haslock(ch) || trylock(ch)        

        if isready(ch)

            value = take!(ch)
            res = f(ch, value) 

            if res isa Break
                terminated = true
                break
            end

            bingo = false 

        end

    end
    
    return terminated

end


function unlock_channels(chvec::Vector{Channel})

    for ch in chvec
        haslock(ch) || unlock(ch)
    end

    return nothing
end


function set_conditions!(ch::Channel, cond_wait::Threads.Condition)
    
    lk = cond_wait.lock

    ch.cond_wait = cond_wait
    ch.cond_put = Threads.Condition(lk)
    ch.cond_take = Threads.Condition(lk)

    return nothing
end

function restore_conditions!(ch::Channel)
    
    lk = ReentrantLock()

    old_cond_put = ch.cond_put
    
    ch.cond_wait = Threads.Condition(lk)
    ch.cond_put = Threads.Condition(lk)
    ch.cond_take = Threads.Condition(lk)

    if length(old_cond_put.waitq) > 0
        
        @info "Unblock producer from `wait(ch.cond_put)`"
        
        el = popfirst!(old_cond_put.waitq)
        push!(ch.cond_put.waitq, el)
        notify(old_cond_put)
    end

    return nothing
end



"""
    _receive_blocking(f::Function, ch_vec::Vector{Channel})

Takes values from channels in a ready state. If none is ready waits
for `cond_wait` to be triggered. It is assumed that the thread owns a
lock of for the condition and that all channels have the same
`cond_wait`.
"""
function _receive_blocking(f::Function, ch_vec::Vector{Channel})

    c = ch_vec[1].cond_wait

    N = length(ch_vec)

    k = 1
    j = 1

    bingo = false 

    while true

        if k == j
            j = mod(j, N) + 1
            k = j

            # It seems like an unfortunate race condition here :( 
            if bingo 
                wait(c)
            end

            bingo = true
        end

        k = mod(k, N) + 1

        ch = ch_vec[k]

        if isready(ch)

            value = take!(ch)

            res = f(ch, value) 

            if res isa Break
                break
            end

            bingo = false 
        end

    end

    return nothing

end



receive(f::Function, ch1::Channel, ch2::Channel) = receive(f, Channel[ch1, ch2])

function receive(f::Function, ch_vec::Vector{Channel})

    # Step 1: Acquire locks for channels and meanwhile take the values
    # from channels in nonblocking way. To prevent starvation the order
    # of channels are permuted like 123 231 312 for three channels.

    terminated = false
    try 
        terminated = _receive_nonblocking(f, ch_vec)
    catch err
        terminated = true
        rethrow(err)
    finally
        if terminated
            unlock_channels(ch_vec)
            return nothing
        end        
    end

    

    # Step 2: Replace every channel conditions with new ones having
    # the same lock and for cond_wait the same condition.

    lk = ReentrantLock()
    c = Threads.Condition(lk)

    lock(lk)

    for ch in ch_vec
        olk = ch.cond_wait.lock
        set_conditions!(ch, c)
        unlock(olk)
    end
    
    # Step 3: Takes values from channels in a ready state. If none is
    # ready waits for `cond_wait` to be triggered. To prevent
    # starvation the order of channels are permuted like 123 231 312
    # for three channels.

    try
        
        _receive_blocking(f, ch_vec)

    finally

        # Step 4: Cleanup.
        
        for ch in ch_vec
            restore_conditions!(ch)
        end
        
        unlock(lk)

    end

    return nothing

end


export receive

end # module
