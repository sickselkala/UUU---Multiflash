<#
.SYNOPSIS
    Flasher parallelo per più dispositivi basato su uuu (Universal Update Utility).
.DESCRIPTION
    Monitora i dispositivi USB connessi, avvia processi di flash uuu in parallelo e 
    fornisce un pannello di stato dinamico che mostra i processi in corso e quelli completati,
    indicando la porta USB, lo stato di successo/fallimento e i log per il debug.
    
.PARAMETER UuuExe
    Percorso completo dell'eseguibile uuu.exe.

.PARAMETER UuuScript
    Percorso completo dello script uuu.auto da eseguire.

.PARAMETER DevicePrefix
    Prefisso da usare per nominare i dispositivi nell'interfaccia (es. "PC SECO", "Device"). Default: "Device".

.PARAMETER LogFile
    Percorso del file di log principale dove verranno registrati tutti gli eventi.

.EXAMPLE
    .\multiFlash_v2.ps1
    (Esegue lo script con i percorsi di default)

.EXAMPLE
    .\Seco-MultiFlash-v2.ps1 -UuuExe "C:\flasher\uuu.exe" -UuuScript "C:\flasher\script.auto"
    (Esegue lo script specificando percorsi personalizzati)

.VERSION
    1.0 - versione base
    2.0 - Miglioramenti:
            1. Parametri per configurazione flessibile.
            2. Gestione avanzata degli errori (cattura ExitCode di uuu).
            3. Interfaccia utente dinamica con stato in tempo reale.
            4. Log specifici per ogni sessione di flash per un debug più semplice.
    V 2.1 - CM 15/10/2025 - Aggiunta visualizzazione porta USB nella UI.
#>

# ==================== SEZIONE 1: CONFIGURAZIONE====================
param (
    [string]$UuuExe = "D:\SECO\release-6.4-tvm32-flasher\sysroots\cortexa9t2hf-neon-fslc-linux-gnueabi\usr\share\sigma-flasher\uuu.exe",
    [string]$UuuScript = "D:\SECO\release-6.4-tvm32-flasher\sysroots\cortexa9t2hf-neon-fslc-linux-gnueabi\usr\share\sigma-flasher\uuu.auto",
    [string]$DevicePrefix = "Device",
    [string]$LogFile = ".\multiflash_main.log"
)

# --- Configurazione Dispositivi ---
$DevicesToMonitor = @(
    @{ VID = "15A2"; PID = "0054" }
)

# --- Impostazioni Operative ---
$PollInterval = 2 # Intervallo di aggiornamento in secondi

# ==================== SEZIONE 2: INIZIALIZZAZIONE VARIABILI ====================

$running = @{}
$deviceNames = @{}
$deviceCounter = 0
$completedJobs = [System.Collections.Generic.List[PSCustomObject]]::new()

function Log-Event {
    param($text)
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $text" | Out-File -FilePath $LogFile -Append
}

# Verifica iniziale dei percorsi
if (-not (Test-Path $UuuExe)) {
    Write-Host "ERRORE: Eseguibile uuu.exe non trovato al percorso '$UuuExe'. Correggere il parametro -UuuExe." -ForegroundColor Red
    exit
}
if (-not (Test-Path $UuuScript)) {
    Write-Host "ERRORE: Script uuu.auto non trovato al percorso '$UuuScript'. Correggere il parametro -UuuScript." -ForegroundColor Red
    exit
}

# ==================== SEZIONE 3: LOOP PRINCIPALE DI MONITORAGGIO ====================

Log-Event "******************** AVVIO MULTI-DEVICE FLASH UTILITY v2.1 ********************"
Log-Event "Immagine target: (definita in $UuuScript)"

while ($true) {
    try {
        # --- Rilevamento nuovi dispositivi ---
        foreach ($devFilter in $DevicesToMonitor) {
            # ... (logica di rilevamento identica a prima)
            $usbVid = $devFilter.VID
            $usbPid = $devFilter.PID
            $devices = Get-PnpDevice | Where-Object { $_.InstanceId -match "USB\\VID_$usbVid&PID_$usbPid" -and $_.Present }

            foreach ($dev in $devices) {
                $locInfo = (Get-PnpDeviceProperty -InstanceId $dev.InstanceId -KeyName 'DEVPKEY_Device_LocationInfo').Data
                
                if ($locInfo -and $locInfo -match "Port_#0*([0-9]+)\.Hub_#0*([0-9]+)") {
                    $port = [int]$matches[1]
                    $hub = [int]$matches[2]
                    $usbPath = "${hub}:${port}"

                    if (-not $running.ContainsKey($usbPath)) {
                        # ... (logica di assegnazione nome identica)
                        if (-not $deviceNames.ContainsKey($usbPath)) {
                            $deviceCounter += 1
                            $deviceNames[$usbPath] = "$DevicePrefix $deviceCounter"
                        }
                        $deviceName = $deviceNames[$usbPath]

                        # --- Creazione file batch e log specifici per il job ---
                        $jobTimestamp = Get-Date -Format "yyyyMMddHHmmss"
                        $batFile = "$env:TEMP\uuu_${hub}_${port}.bat"
                        $jobLogFile = "$env:TEMP\uuu_${hub}_${port}_${jobTimestamp}.log"
                        
                        $batContent = @"
@echo off
echo Log del processo per $deviceName su porta $usbPath
echo Avviato il: $(Get-Date)
echo.
"$UuuExe" -m $usbPath "$UuuScript" >> "$jobLogFile" 2>&1
exit /b %errorlevel%
"@
                        $batContent | Out-File -FilePath $batFile -Encoding ASCII

                        $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$batFile`"" -PassThru -WindowStyle Hidden

                        # Aggiungi il processo alla tabella di monitoraggio
                        $running[$usbPath] = [PSCustomObject]@{
                            Process   = $proc
                            StartTime = Get-Date
                            BatchFile = $batFile
                            JobLog    = $jobLogFile
                            Name      = $deviceName
                            Port      = $port  # <-- MODIFICATO: Aggiunta della porta
                        }
                        
                        $logMessage = "Flash AVVIATO per $deviceName (Porta USB $port) | ID Job: $($proc.Id)"
                        Log-Event $logMessage
                    }
                }
            }
        }

        # --- Controllo processi terminati ---
        $toRemove = @()
        foreach ($entry in $running.GetEnumerator()) {
            $usbKey = $entry.Key
            $info = $entry.Value
            
            if ($info.Process.HasExited) {
                $endTime = Get-Date
                $duration = New-TimeSpan -Start $info.StartTime -End $endTime
                $exitCode = $info.Process.ExitCode
                $status = if ($exitCode -eq 0) { "SUCCESSO" } else { "FALLITO (Codice: $exitCode)" }
                
                $logMessage = "Flash TERMINATO per $($info.Name) | Stato: $status | Durata: $($duration.ToString('g'))"
                Log-Event $logMessage
                if ($status -ne "SUCCESSO") {
                    Log-Event " -> Dettagli errore nel file: $($info.JobLog)"
                }

                # Aggiungi ai job completati per la UI
                $completedJobs.Add([PSCustomObject]@{
                    Name     = $info.Name
                    Port     = $info.Port # <-- MODIFICATO: Aggiunta della porta
                    Status   = $status
                    Duration = $duration.ToString('g')
                    EndTime  = $endTime.ToString('HH:mm:ss')
                    LogFile  = $info.JobLog
                })

                $toRemove += $usbKey
                Remove-Item $info.BatchFile -ErrorAction SilentlyContinue
            }
        }
        foreach ($k in $toRemove) { $running.Remove($k) }

    } catch {
        Log-Event "ERRORE CRITICO NEL CICLO DI MONITORAGGIO: $_"
    }

    # ==================== SEZIONE 5: INTERFACCIA UTENTE DINAMICA ====================
    Clear-Host
    Write-Host "********************** MULTI-DEVICE FLASH UTILITY v2.1 *********************" -ForegroundColor Yellow
    Write-Host "Immagine: $($UuuScript.Split('\')[-1])"
    Write-Host "Monitoraggio attivo... (Premi CTRL+C per uscire)"
    Write-Host "--------------------------------------------------------------------------"
    
    # Tabella processi in corso
    Write-Host "`n--- DISPOSITIVI IN FLASH ---`n"
    if ($running.Count -eq 0) {
        Write-Host "Nessun processo attivo. In attesa di un dispositivo..." -ForegroundColor Gray
    } else {
        $running.GetEnumerator() | ForEach-Object {
            $elapsed = (New-TimeSpan -Start $_.Value.StartTime).ToString('g')
            # <-- MODIFICATO: Aggiunto $_.Value.Port alla stringa di formato
            $displayText = "{0,-15} (Porta: {1,-2}) | {2,-20} | In corso da: {3}" -f $_.Value.Name, $_.Value.Port, "Stato: IN ESECUZIONE", $elapsed
            Write-Host $displayText -ForegroundColor Cyan
        }
    }
    
    # Tabella processi completati (mostra gli ultimi 10)
    Write-Host "`n--- STORICO SESSIONE (ultimi 10) ---`n"
    if ($completedJobs.Count -eq 0) {
        Write-Host "Nessun processo ancora completato." -ForegroundColor Gray
    } else {
        $completedJobs | Select-Object -Last 10 | ForEach-Object {
            $color = if ($_.Status -match "SUCCESSO") { "Green" } else { "Red" }
            $statusText = if ($_.Status -match "FALLITO") {
                "$($_.Status) - Vedi log: $($_.LogFile.Split('\')[-1])" # Mostra solo il nome del file per brevità
            } else {
                $_.Status
            }
            # <-- MODIFICATO: Aggiunto $_.Port alla stringa di formato
            $displayText = "{0,-15} (Porta: {1,-2}) | {2,-55} | Durata: {3}" -f $_.Name, $_.Port, "Stato: $statusText", $_.Duration
            Write-Host $displayText -ForegroundColor $color
        }
    }
    Write-Host "`n--------------------------------------------------------------------------"
     # ==================== SEZIONE 6: GESTIONE INPUT UTENTE ====================
    # Controlla se un tasto è stato premuto senza bloccare l'esecuzione.
    if ([System.Console]::KeyAvailable) {
        # Legge il tasto premuto senza mostrarlo a schermo
        $key = [System.Console]::ReadKey($true)

        # Se il tasto è 'r' (indipendentemente da maiuscolo/minuscolo)
        if ($key.Key -eq 'R') {
            # Esegue il reset
            $completedJobs.Clear()
            $deviceCounter = 0
            $deviceNames.Clear()
            Log-Event "--- INTERFACCIA E CONTATORI RESETTATI DALL'UTENTE ---"
        }
    }
    # ===========================================================================
    
    Start-Sleep -Seconds $PollInterval
}