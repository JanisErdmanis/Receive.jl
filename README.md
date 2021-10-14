# Receive.jl

Programming concurrent systems are hard. Go has shown that such systems become easier when expressed with select statements that enable timeouts, heartbeat, termination of workers, state machines with multiple inputs, and other sound patterns. We can also express these patterns in Erlang with a receive statement which I implemented here as follows:


``` julia
using Receive: receive, Break

let

state = 0

receive(results, quit) do ch, value
    
   if ch==quit
       close(quit)
       return Break()
   end

   state = value
end

end
```

**WARNING: This implementation is experimental and unforeseen races which lead to deadlocks are likely**


## Resources

  * https://github.com/nomad-software/go-channel-compendium
  * <https://github.com/golang/go/blob/master/src/runtime/select.go>
  * https://stackoverflow.com/questions/37021194/how-are-golang-select-statements-implemented
