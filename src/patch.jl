# Need to patch up a put! method in order to deal with situation where
# conditions for the channel change while waiting for a lock.

using Base: check_channel_state

function Base.put_unbuffered(c::Channel, v)

    lk = c.cond_take.lock
    lock(lk)

    # relock to support clean exit from receive
    if lk != c.cond_take.lock
        @info "Relocked"

        unlock(lk)
        lk = c.cond_take.lock
        lock(lk)
    end

    taker = try
        while isempty(c.cond_take.waitq)
            check_channel_state(c)
            notify(c.cond_wait)
            wait(c.cond_put)
        end
        # unfair scheduled version of: notify(c.cond_take, v, false, false); yield()
        popfirst!(c.cond_take.waitq)
    finally
        unlock(lk)
    end
    schedule(taker, v)
    yield()  # immediately give taker a chance to run, but don't block the current task
    return v
end
