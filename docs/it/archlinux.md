# Giuda di installazione Archlinux (by 7ir3)

Lo scopo di questa guida è illustrare **step by step** (o command-by-command) come installare un sistema Linux basato su [Archlinux](https://archlinux.org/) con un focus maggiore per quanto riguarda tutti quegli aspetti di sicurezza e stabilità del sistema.

Per ogni sezione verrà descritta nel dettaglio le ragioni delle scelte dei comandi usati, però in breve ecco alcuni punti salienti che riguardano il sistema.

- Filesystem basato su [**BtrFS**](https://wiki.archlinux.org/title/Btrfs) per garantire una stabilità e revertibilità del sistema in caso di problemi grazie alla sua funzionalità di **snapshots** e possibilità di dividere il sistema in **subvolumes** per ogni categoria o caso d'uso di necessità.
- Cifratura delle partizioni di `/` e `/boot` per garantire massima sicurezza e segretezza delle informazioni del sistema in caso di accesso fisico alla macchina da parte di autori malevoli. Questo aspetto è molto importante quando si parla di macchine host portatili o aziendali.
- **Contenerizzazione** delle applicazioni (sia in **system environment** che in **user environment**) attraverso strumenti come `flatpak` che permettono di installare applicazioni in modo contenerizzato attraverso il proprio store [flathub](https://flathub.org/).

todo: index

---

## 0. Download dell'immagine Archlinux e creazione di un dispositivo di supporto per la ISO

## 1. Preparazione e configurazione dell immagine ISO `archiso`

I primi task da eseguire appena entrati nell'immagine di installazione di Archlinux (`archiso`) sono quelli di configurazione di alcuni aspetti come **layout di tastiera**, **locale** e **tweak di pacman** per una corretta e migliore esperienza in fase di installazione.

> [!NOTE]
> In caso di connessione wireless, è necessario far connettere l'immagine ISO alla rete WiFi. Per fare ciò `archiso` mette a disposizione il package [`iwd`](https://wiki.archlinux.org/title/Iwd), in particolare il comando [`iwctl`](https://man.archlinux.org/man/iwctl.1) per connettersi alle reti wireless.
> Per connettersi a una determinata rete, eseguire:
>
> ``` bash
> iwctl --passphrase=PASSPHRASE station DEVICE connect SSID
> ```



### 1.1 (Consigliato!) Configurazione SSH per installazione remota

Di seguito vengono mostrati gli step necessarri per abilitare [**SSH**](https://wiki.archlinux.org/title/OpenSSH) per un installazione del sistema remota usando il proprio sistema host di preferanza.

> [!TIP]
> Questo step è molto consigliato perché permette di seguire la guida in modo facile e immettendo i vari comandi con un semplice e classicissimo **copy/paste**.

1. Imposta una password per l'utente `root`: usa il comando [`passwd`](https://man.archlinux.org/man/passwd.1)
2. Abilita il servizio di **SSH** ([Daemon management](https://wiki.archlinux.org/title/OpenSSH#Daemon_management)): `systemctl start sshd.service`
3. Controllare l'indirizzo IP corrente assegnato alla macchina: `ip a`

Dalla propria macchina host, collegarsi alla **target machine** usando il comando:

``` bash
ssh root@IP
```

Immetete la password scelta allo step 1. e siete pronti per proseguire con la guida di installazione.

## 2. Partizionamento e formattazione del disco

Per ottenere le garanzie di sicurezza in tema di **cifratura** e **segregazione** del sistema e delle applicazioni di *sistema* e *utente* il disco viene partizionato nel seguente layout.

``` text
/dev/sda

+-------+---------+-----------+
|       |         |           |
|  EFI  |  /boot  |  LVM (/)  |
|       |         |           |
+-------+---------+-----------+
```

> [!TIP]
> Viene usato come riferimento `/dev/sda` come disco target, utilizzare il comando [`lsblk`](https://wiki.archlinux.org/title/Device_file#lsblk) per capire quale è il proprio disco target dove si vuole installare il sistema.

Questo layout permette in primis di cifrare le partizioni di **/boot** e **/**. Lasciando solo la partizione **EFI** non cifrata, ma quest'ultima e necessaria che sia in chiaro perché contiene il **bootloader** (più avanti nella guida verra descritto quale è il bootloader scelto ed eventuali riferimenti alla documentazione necessari) che deve essere caricato all'avvio del sistema.

[**LVM**](https://wiki.archlinux.org/title/LVM) permette di creare volumi logici, necessari per creare un layer aggiuntivo di **segregazione** del sistema, semparando la partizione di **/** con quella di **/home**. Per ottenere tale garanzia vengono creati i **volumi logici** seguendo il medesimo layout.

``` text
archlinux (o qualsiasi nome del volume fisico logico creato per /)

+------------------+------------------+------------------+
|                  |                  |                  |
|  archlinux-swap  |  archlinux-root  |  archlinux-home  |
|                  |                  |                  |  
+------------------+------------------+------------------+
```

> [!NOTE]
> Di seguito, verrannò indicate le dimensioni consigliate per ogno **volume logico** LVM.

### 2.1 Rimozione dei dati e partizionamento del disco

È necessario **pulire** il disco da eventuali dati presenti sul disco prima di formattare il discono nelle 3 partizioni previste.

Vengono utilizzati i comandi [`wipefs`](https://man.archlinux.org/man/wipefs.8.en) e [`sgdisk`](https://man.archlinux.org/man/sgdisk.8.en) in questa fase.

``` bash
wipefs -af /dev/sda
sgdisk --zap-all --clear /dev/sda
```

>[!NOTE]
> Ad ogni operazione sul disco, che riguarda il cambiamento del disco in termini di **dati** e **tabelle delle partizioni GPT**, usare il comando [`partprobe /dev/sda`](https://man.archlinux.org/man/partprobe.8.en) per informare il **kernel** di tali cambiamenti.

Ora è possibile formattare i disco nelle **3 partizioni** richieste dal layout definito in precedenza:

- **EFI**, `sgdisk --set-alignment=4096 -n 1:0:+512M -t 1:ef00 /dev/sda`
- **/boot**, `sgdisk --set-alignment=4096 -n 2:0:+1G -t 2:8300 /dev/sda`
- **/**, `sgdisk --set-alignment=4096 -n 3:0:0 -t 3:8309 /dev/sda`

> [!TIP]
> Le grandezze di ogni partizione è possibile cambiarle a proprio piacimento, alcuni consigli:
>
> - **EFI** < 512M
> - **/boot** < 1G, ma non più grande di 5G
>
> Per quanto riguarda **/**, prende il restante spazio rimasto sul disco dalle grandezze delle partizioni precedenti.

### 2.1.1 (Opzionale) Zero-out delle partizioni

Consigliato effettuare una procedura di **zero-out** su ogni partizione. Questa procedura grantisce di pulire tutte le partizioni da eventuali dati sporchi ancora presenti, andando a scrivere vari `0` su ogni partizione indicata.

``` bash
cat /dev/zero > /dev/sda1
cat /dev/zero > /dev/sda2
cat /dev/zero > /dev/sda3
```

## 2.2 Cifratura del disco

Procediamo con la cifratura del disco, in particolare della partizione `3`, quella di **/**.

Usiamo il tool [`cryptsetup`](https://man.archlinux.org/man/cryptsetup.8.en) che viene fornito dal modulo kernel **dm-crypt** precedentemente caricato nel sistema.

> [!IMPORTANT]
> Quando viene eseguto il comando `echo` in pipe con il comando `cryptsetup`, viene passata una stringa di valore **changeme**, quella è la chiave di cifratura del sistema, quindi cambiate di conseguenza e sostituite tale valore anche nei successivi comandi dove viene utilizzata.
>
> Inoltre la partizione cifrata, quando viene aperta, viene etichettata come **cryptdev**, anche questa etichettata cambiatela a preferenza e sostituite tale valore nei comandi successivi. Questa etichetta serve per mappare il disco cifrato grazie al modulo kernel caricato il precedenza **dm-mod**.

``` bash
echo -n 'changeme' | cryptsetup -v -y luksFormat /dev/sda3 \
 --batch-mode \
 --type luks2 \
 --cipher aes-xts-plain64 \
 --key-size 512 \
 --hash sha512 \
 --pbkdf pbkdf2 \
 --pbkdf-force-iterations 100000
echo -n 'changeme' | cryptsetup open /dev/sda3 cryptdev
```

Come si può notare, al momento solo la partizione `sda3` è stata cifrata, al momento la partizione `sda2` (quella di **/boot**) rimane in chiaro perché verrà cifrata successivamente in fase di generazione dell'immagine di sistema.

## 2.3 LVM

Occupiamoci di creare i **volumi logici** nella partizione di **/** per rispettare il layout definito il precedenza per separare le partizioni di **root**, **home** e **swap** tra di loro.

> [!NOTE]
> Per il volume logico **master** viene assegnata l'etichetta **archlinux**, in base a che etichetta viene scelta, cambiate il riferimento all'etichetta e anche nei comandi sucessivi `ETICHETTA-root`, `ETICHETTA-home` e `ETICHETTA-swap`.

``` bash
pvcreate /dev/mapper/cryptdev
vgcreate archlinux /dev/mapper/cryptdev
```

Creiamo i volumi per ogni partizione logica che vogliamo avere nel sistema:

- **swap**, dimensione consigliata **512M** oppure **RAM + 2G**: `lvcreate -n swap -L 18G archlinux`
- **root**, dimensione consigliata tra **50G** a **200G**, in base alla dimensione del vostro disco: `lvcreate -n root -L 50G archlinux`
- **home**, viene usato lo spazio rimanete sul disco: `lvcreate -n home -l +100%FREE archlinux`

## 2.4 Formattazione delle partizioni

Per ogni partizione creata precedentemente, si formatta con il **filesystem** coerente al loro utilizzo e tipologia di partizione definita in fase di partizionamento del disco.

Viene utilizzato il comando [`mkfs`](https://wiki.archlinux.org/title/File_systems#Create_a_file_system) per creare il filesystem desiderato. Invece per la **swap** viene usato il comando [`mkswap`](https://wiki.archlinux.org/title/Swap#Swap_partition).

- **EFI**, `mkfs.fat -F32 /dev/sda1`
- **/boot**, `mkfs.ext4 /dev/sda2`
- **/ (LVM)**:
  
  - **root**, `mkfs.btrfs -L root /dev/mapper/archlinux-root`
  - **home**, `mkfs.btrfs -L home /dev/mapper/archlinux-home`
  - **swap**, `mkswap /dev/mapper/archlinux-swap`

Ora attiviamo anche la **swap**, questo serve per essere vista quando viene generato il file `/etc/fstab` tramite il comando [`genfstab`](https://wiki.archlinux.org/title/Genfstab) nel prossimo step.

``` bash
swapon /dev/mapper/archlinux-swap
swapon -a
```

## 2.5 BtrFS

## Montaggio di EFI e /boot