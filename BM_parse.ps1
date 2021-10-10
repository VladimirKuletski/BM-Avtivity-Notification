﻿$VerbosePreference = "continue"


Try{
    Do{
        $WS = New-Object System.Net.WebSockets.ClientWebSocket                                                
        $CT = New-Object System.Threading.CancellationToken($false)
        $CTS = New-Object System.Threading.CancellationTokenSource

        $WS.Options.UseDefaultCredentials = $true
        $Conn = $WS.ConnectAsync('wss://api.brandmeister.network/lh/%7D/?EIO=3&transport=websocket', $CTS.Token)                                                  
        While (!$Conn.IsCompleted) { Start-Sleep -Milliseconds 100 }

        Write-Verbose "Connected to BM"
        Write-Verbose $WS.State

        $Size = 1024
        $Array = [byte[]] @(,0) * $Size
        $Recv = New-Object System.ArraySegment[byte] -ArgumentList @(,$Array)
        $last_message_id = ""

        While ($WS.State -eq 'Open') {

            $RTM = ""
        
            Do {
                $Conn = $WS.ReceiveAsync($Recv, $CT)
                While (!$Conn.IsCompleted) { Start-Sleep -Milliseconds 10 }

                $Recv.Array[0..($Conn.Result.Count - 1)] | ForEach { $RTM += [char]$_ }
       
            } Until ($Conn.Result.Count -lt $Size)

            if ($RTM.IndexOf("3120610") -ne -1) {
                Write-Verbose $RTM
            }
            
            if (($RTM.Substring(0,2) -eq "42" ) -and ($RTM.IndexOf("Session-Update") -ne -1)) {
                $RTM = $RTM.Substring(10,$RTM.Length-1-10) # cut BM message type
                $RTM = ($RTM | convertfrom-json) # convert to json object
                $RTM = ($RTM.payload | convertfrom-json) # extract "payload" string and convert to json object
                # Write-Verbose $RTM
                if (($RTM.DestinationID -eq "91") -and ($last_message_id -ne $RTM.SessionID) -and ($RTM.Stop -ne "0")) {
                    # Write-Verbose $RTM
                    if ($RTM.SourceName) {
                        Write-Verbose "$($RTM.SourceCall + ' ' + $RTM.SourceName)"
                    }
                    elseif ($RTM.TalkerAlias){
                        Write-Verbose $RTM.TalkerAlias
                    }
                    else {
                        Write-Verbose $RTM.SourceID
                    }

                    $last_message_id = $RTM.SessionID
                }
            }
        }   
    } Until (!$Conn)

}Finally{

    If ($WS) { 
        Write-Verbose "Closing websocket"
        $WS.Dispose()
    }

}