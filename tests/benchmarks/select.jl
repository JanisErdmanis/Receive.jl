function receive_select(f::Function, ch1::Channel, ch2::Channel)

    while true
        
        result = @select begin
            ch1 |> value => begin
                f(ch1, value)
            end
            ch2 |> value => begin
                f(ch2, value)
            end
        end

        if result isa Break
            break
        end
    end

end


