# PowerShell Multi-Device Flash Utility

Uno script PowerShell per il flashing parallelo di più dispositivi utilizzando l'utility `uuu` (Universal Update Utility) di NXP. Lo script monitora le connessioni USB, avvia processi di flashing indipendenti per ogni dispositivo rilevato e fornisce un'interfaccia utente dinamica nel terminale per monitorare lo stato in tempo reale.

## Prerequisiti

Questo script **non include** UUU. È necessario aver già installato lo strumento UUU ufficiale, disponibile qui:
* **Repository Ufficiale NXP UUU:** [https://github.com/nxp-imx/mfgtools](https://github.com/nxp-imx/mfgtools)

## Caratteristiche Principali

- **Flashing Parallelo**: Avvia un processo `uuu` separato per ogni dispositivo connesso, massimizzando l'efficienza.
- **Rilevamento Automatico**: Monitora costantemente le porte USB per nuovi dispositivi corrispondenti a VID/PID specificati.
- **Interfaccia Utente Dinamica**: Mostra una dashboard chiara e aggiornata automaticamente con:
  - Dispositivi attualmente in fase di flashing.
  - Storico dei processi completati (ultimi 10).
  - Stato di successo o fallimento per ogni processo.
  - Durata del flashing.
- **Gestione Avanzata degli Errori**: Cattura il codice di uscita del processo `uuu` per determinare con precisione se il flashing è riuscito o fallito.
- **Reset Interattivo**: È possibile resettare lo storico e i contatori dei dispositivi premendo il tasto `R` senza interrompere lo script.
- **Log Dettagliati**:
  - Un file di log principale per gli eventi di alto livello (avvio/fine/errori critici).
  - Un file di log specifico per ogni sessione di flashing, contenente l'output completo di `uuu` per un facile debug.
- **Configurazione Flessibile**: I percorsi per `uuu.exe` e lo script `uuu.auto` possono essere passati come parametri all'avvio.
- **Reset Interattivo**: È possibile resettare lo storico e i contatori dei dispositivi premendo il tasto `R` senza interrompere lo script.

## Prerequisiti

1.  **Sistema Operativo**: Windows 10 o successivo.
2.  **PowerShell**: Versione 5.1 o superiore (generalmente preinstallata su Windows 10).
3.  **Utility `uuu`**: È necessario disporre dell'eseguibile `uuu.exe` e di uno script di comandi `uuu.auto` valido e funzionante.

## Configurazione

Prima di eseguire lo script, è necessario configurare alcuni percorsi. È possibile farlo in due modi:

### 1. Modifica Diretta dello Script (Metodo Predefinito)

Apri il file `multiFlash_v2.ps1` e modifica i valori predefiniti nel blocco `param`:

```powershell
param (
    [string]$UuuExe = "C:\percorso\completo\del\tuo\uuu.exe",
    [string]$UuuScript = "C:\percorso\completo\del\tuo\uuu.auto",
    [string]$DevicePrefix = "Device",
    [string]$LogFile = ".\multiflash_main.log"
)
```

Assicurati anche che i `VID` e `PID` nel blocco `$DevicesToMonitor` corrispondano a quelli del tuo dispositivo in modalità flashing:

```powershell
# --- Configurazione Dispositivi ---
$DevicesToMonitor = @(
    @{ VID = "15A2"; PID = "0054" } # Esempio per i.MX
)
```

### 2. Tramite Parametri da Riga di Comando

Puoi specificare i percorsi direttamente all'avvio dello script, sovrascrivendo i valori predefiniti.

## Utilizzo

1.  Apri un terminale PowerShell.
2.  Naviga fino alla directory contenente lo script.
3.  Esegui lo script.

**Esecuzione con configurazione predefinita:**
```powershell
.\multiFlash_v2.ps1
```

**Esecuzione specificando percorsi personalizzati:**
```powershell
.\multiFlash_v2.ps1 -UuuExe "D:\flasher\uuu.exe" -UuuScript "D:\flasher\script.auto"
```

Una volta avviato, lo script inizierà a monitorare i dispositivi. Collega un dispositivo SECO a una porta USB per avviare automaticamente il processo di flashing.

### Comandi Interattivi

- **`CTRL+C`**: Interrompe lo script e termina il monitoraggio.
- **`R`**: (mentre lo script è in esecuzione) Resetta lo storico della sessione e il contatore dei dispositivi. Utile se si vuole iniziare una nuova "batch" di flashing senza riavviare lo script.

## Interfaccia Utente

L'interfaccia è divisa in due sezioni principali:

### DISPOSITIVI IN FLASH

Mostra i dispositivi per cui è attualmente in corso un'operazione di flashing.
- **Colore Ciano**: Processo in esecuzione.
- Vengono visualizzati il nome progressivo del dispositivo (`PC SECO N`), la porta USB, e il tempo trascorso dall'inizio.

### STORICO SESSIONE

Mostra un elenco degli ultimi 10 processi di flashing completati in quella sessione.
- **Colore Verde**: Il flashing è terminato con **successo**.
- **Colore Rosso**: Il flashing è **fallito**. In questo caso, viene mostrato il codice di errore e il nome del file di log specifico da consultare per i dettagli.

## Troubleshooting

Se un flashing fallisce (`FALLITO`), controlla il file di log associato a quel job. Il nome del file di log viene mostrato nell'interfaccia (es. `uuu_HUB_PORT_TIMESTAMP.log`) e si trova nella directory temporanea del tuo utente (`$env:TEMP`). Questo file contiene l'output completo di `uuu.exe` e ti aiuterà a diagnosticare il problema.

Il file di log principale (`seco_multiflash_main.log` per impostazione predefinita) contiene invece una cronologia di tutti gli eventi di avvio e fine.
