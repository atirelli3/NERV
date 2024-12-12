![Arch Linux Logo](https://archlinux.org/static/logos/archlinux-logo-dark-scalable.518881f04ca9.svg)

# Guida di Installazione Arch Linux (by 7ir3)

Lo scopo di questa guida è illustrare **step by step** (o command-by-command) come installare un sistema Linux basato su [Arch Linux](https://archlinux.org/) con un focus particolare sugli aspetti di sicurezza e stabilità del sistema.

Per ogni sezione verranno descritte nel dettaglio le ragioni delle scelte dei comandi utilizzati. Tuttavia, ecco un breve riepilogo dei punti salienti relativi al sistema:

- **Filesystem Btrfs**: L'installazione utilizza il [**BtrFS**](https://wiki.archlinux.org/title/Btrfs) per garantire stabilità e la possibilità di eseguire rollback in caso di problemi. Grazie alle sue funzionalità di **snapshot** e la capacità di dividere il sistema in **subvolumi**, BtrFS offre una gestione flessibile e resiliente del filesystem.
- **Cifratura delle Partizioni**: Le partizioni di `/` e `/boot` vengono cifrate per garantire massima sicurezza e protezione dei dati in caso di accesso fisico non autorizzato. Questo è un aspetto cruciale per macchine portatili o sistemi aziendali.
- **Contenerizzazione delle Applicazioni**: La guida include l'uso di strumenti come `flatpak` per gestire le applicazioni in modo contenitore, sia nell'ambiente di sistema che utente. Questo approccio migliora l'isolamento e la gestione delle applicazioni, utilizzando lo store [Flathub](https://flathub.org/) come fonte principale.

todo: index

---

## 0. Download dell'immagine Archlinux e creazione di un dispositivo di supporto per la ISO

todo: scrivere come montare l'immagine iso su una ubs da terminale o usando software.

## 1. Preparazione e Configurazione dell'Immagine ISO `archiso`

I primi task da eseguire appena entrati nell'immagine di installazione di Arch Linux (`archiso`) sono relativi alla configurazione di alcuni aspetti come il **layout di tastiera**, **locale** e **ottimizzazione di pacman** per una migliore esperienza durante l'installazione.

> [!NOTE]
> In caso di connessione wireless, è necessario collegare l'immagine ISO alla rete WiFi. Per farlo, `archiso` include il package [`iwd`](https://wiki.archlinux.org/title/Iwd), utilizzando in particolare il comando [`iwctl`](https://man.archlinux.org/man/iwctl.1) per connettersi alle reti wireless.
>
> Per connettersi a una determinata rete, eseguire:
>
> ```bash
> iwctl --passphrase=PASSPHRASE station DEVICE connect SSID
> ```

Assicuriamoci che i [**moduli kernel**](https://wiki.archlinux.org/title/Kernel_module) necessari per i tool di **cifratura del disco** e **mapping** siano caricati nel kernel:

- [`dm-crypt`](https://wiki.archlinux.org/title/Dm-crypt)
- [`dm-mod`](https://docs.kernel.org/admin-guide/device-mapper/dm-init.html)

Inoltre, rimuoviamo il modulo kernel dello **speaker** per evitare rumori o beep durante l'installazione:

- [`pcspkr`](https://wiki.archlinux.org/title/PC_speaker)

```bash
modprobe dm-crypt
modprobe dm-mod
rmmod pcspkr
```

Procediamo con la configurazione base di `archiso`:

```bash
loadkeys us

timedatectl set-timezone "Europe/Rome"
timedatectl set-ntp true

sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf
sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 20/' /etc/pacman.conf
sed -i '/#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ {s/^#//}' /etc/pacman.conf

reflector --protocol https --age 6 --sort rate --country Italy,Germany,France --save /etc/pacman.d/mirrorlist
pacman -Syy

pacman -S --noconfirm archlinux-keyring
pacman-key --init
pacman-key --populate archlinux
pacman -Syy
```

> [!NOTE]
> La configurazione di [`pacman`](https://wiki.archlinux.org/title/Pacman) è stata automatizzata utilizzando il comando [`sed`](https://man7.org/linux/man-pages/man1/sed.1.html).
>
> In alternativa, è possibile configurarlo manualmente usando un editor di testo (ad esempio `vim` o `nano`):
>
> ```text
> /etc/pacman.conf
> ------------------------------------------------------------------------------
> VerbosePkgLists
> ParallelDownloads = 20
> ...
> [multilib]
> Include = /etc/pacman.d/mirrorlist
> ```

### 1.1 (Consigliato!) Configurazione SSH per Installazione Remota

Di seguito vengono mostrati gli step necessari per abilitare [**SSH**](https://wiki.archlinux.org/title/OpenSSH) per un'installazione remota del sistema utilizzando il proprio sistema host preferito.

> [!TIP]
> Questo step è fortemente consigliato, poiché consente di seguire la guida in modo più agevole, permettendo di eseguire i comandi con un semplice e pratico **copy/paste**.

1. Imposta una password per l'utente `root` utilizzando il comando [`passwd`](https://man.archlinux.org/man/passwd.1):
   ```bash
   passwd
   ```

2. Abilita il servizio di **SSH** ([Daemon management](https://wiki.archlinux.org/title/OpenSSH#Daemon_management)):
   ```bash
   systemctl start sshd.service
   ```

3. Controlla l'indirizzo IP corrente assegnato alla macchina:
   ```bash
   ip a
   ```

Dalla propria macchina host, collegarsi alla **target machine** utilizzando il comando:

```bash
ssh root@IP
```

Immetti la password scelta allo step 1 e sarai pronto per proseguire con la guida di installazione.

## 2. Partizionamento e Formattazione del Disco

Per garantire sicurezza tramite **cifratura** e **segregazione** del sistema e delle applicazioni (*sistema* e *utente*), il disco verrà partizionato con il seguente layout:

```text
/dev/sda

+-------+---------+-----------+
|       |         |           |
|  EFI  |  /boot  |  LVM (/)  |
|       |         |           |
+-------+---------+-----------+
```

> [!TIP]
> In questa guida si utilizza `/dev/sda` come riferimento per il disco target. Usa il comando [`lsblk`](https://wiki.archlinux.org/title/Device_file#lsblk) per identificare il disco corretto dove installare il sistema.

Questo layout permette di cifrare le partizioni di **/boot** e **/**, lasciando solo la partizione **EFI** non cifrata. La partizione **EFI** deve essere in chiaro per contenere il **bootloader**, indispensabile per l’avvio del sistema. Più avanti nella guida verrà specificato il bootloader scelto e forniti i relativi riferimenti alla documentazione.

L’utilizzo di [**LVM**](https://wiki.archlinux.org/title/LVM) consente di creare volumi logici, aggiungendo un livello di **segregazione** al sistema. Questo permette di separare la partizione di **/** da quella di **/home**. Il layout suggerito per i volumi logici è il seguente:

```text
archlinux (o un nome a scelta per il volume fisico logico creato per /)

+------------------+------------------+------------------+
|                  |                  |                  |
|  archlinux-swap  |  archlinux-root  |  archlinux-home  |
|                  |                  |                  |
+------------------+------------------+------------------+
```

> [!NOTE]
> Di seguito verranno indicate le dimensioni consigliate per ciascun **volume logico** LVM.

### 2.1 Rimozione dei Dati e Partizionamento del Disco

È necessario **pulire** il disco da eventuali dati presenti prima di formattarlo nelle 3 partizioni previste.

Per questa operazione vengono utilizzati i comandi [`wipefs`](https://man.archlinux.org/man/wipefs.8.en) e [`sgdisk`](https://man.archlinux.org/man/sgdisk.8.en):

```bash
wipefs -af /dev/sda
sgdisk --zap-all --clear /dev/sda
```

> [!NOTE]
> Dopo ogni operazione sul disco, che modifica i dati o le tabelle delle partizioni GPT, utilizza il comando [`partprobe /dev/sda`](https://man.archlinux.org/man/partprobe.8.en) per informare il **kernel** dei cambiamenti.

Ora è possibile formattare il disco nelle **3 partizioni** richieste dal layout definito in precedenza:

- **EFI**: `sgdisk --set-alignment=4096 -n 1:0:+512M -t 1:ef00 /dev/sda`
- **/boot**: `sgdisk --set-alignment=4096 -n 2:0:+1G -t 2:8300 /dev/sda`
- **/**: `sgdisk --set-alignment=4096 -n 3:0:0 -t 3:8309 /dev/sda`

> [!TIP]
> Le dimensioni delle partizioni possono essere modificate in base alle esigenze personali. Alcuni suggerimenti:
>
> - **EFI**: consigliato < 512M
> - **/boot**: consigliato tra 1G e 5G
>
> La partizione **/** utilizzerà lo spazio rimanente sul disco, al netto delle dimensioni delle altre partizioni.

#### 2.1.1 (Opzionale) Zero-out delle Partizioni

Consigliato effettuare una procedura di **zero-out** su ogni partizione. Questa procedura garantisce di pulire tutte le partizioni da eventuali dati residui, scrivendo zeri su ogni partizione indicata:

```bash
cat /dev/zero > /dev/sda1
cat /dev/zero > /dev/sda2
cat /dev/zero > /dev/sda3
```

### 2.2 Cifratura del Disco

Procediamo con la cifratura del disco, in particolare della partizione `3`, quella di **/**.

Usiamo il tool [`cryptsetup`](https://man.archlinux.org/man/cryptsetup.8.en) che viene fornito dal modulo kernel **dm-crypt** precedentemente caricato nel sistema.

> [!IMPORTANT]
> Quando viene eseguito il comando `echo` in pipe con il comando `cryptsetup`, viene passata una stringa di valore **changeme**. Questa è la chiave di cifratura del sistema: **sostituisci questo valore con una chiave sicura e personalizzata**. 
> Inoltre, la partizione cifrata viene etichettata come **cryptdev**. Anche questa etichetta può essere personalizzata. Sostituisci il valore nei comandi successivi se decidi di cambiarla. Questa etichetta serve per mappare il disco cifrato utilizzando il modulo kernel **dm-mod** caricato in precedenza.

```bash
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

Come si può notare, al momento solo la partizione `sda3` è stata cifrata. La partizione `sda2` (quella di **/boot**) rimane in chiaro perché verrà cifrata successivamente durante la generazione dell'immagine di sistema.

### 2.3 LVM

Occupiamoci di creare i **volumi logici** nella partizione di **/** per rispettare il layout definito in precedenza, separando le partizioni di **root**, **home** e **swap** tra di loro.

> [!NOTE]
> Per il volume logico **master** viene assegnata l'etichetta **archlinux**. In base all'etichetta scelta, ricordati di modificare il riferimento nei comandi successivi per `ETICHETTA-root`, `ETICHETTA-home` e `ETICHETTA-swap`.

```bash
pvcreate /dev/mapper/cryptdev
vgcreate archlinux /dev/mapper/cryptdev
```

Creiamo i volumi per ogni partizione logica:

- **swap**, dimensione consigliata: **512M** oppure **RAM + 2G**:
  ```bash
  lvcreate -n swap -L 18G archlinux
  ```
- **root**, dimensione consigliata: tra **50G** e **200G**, in base alla dimensione del disco:
  ```bash
  lvcreate -n root -L 50G archlinux
  ```
- **home**, utilizza lo spazio rimanente sul disco:
  ```bash
  lvcreate -n home -l +100%FREE archlinux
  ```

### 2.4 Formattazione delle Partizioni

Per ogni partizione creata precedentemente, si formatta con il **filesystem** coerente al loro utilizzo e tipologia di partizione definita in fase di partizionamento del disco.

Viene utilizzato il comando [`mkfs`](https://wiki.archlinux.org/title/File_systems#Create_a_file_system) per creare il filesystem desiderato. Invece per la **swap** viene usato il comando [`mkswap`](https://wiki.archlinux.org/title/Swap#Swap_partition).

- **EFI**, `mkfs.fat -F32 /dev/sda1`
- **/boot**, `mkfs.ext4 /dev/sda2`
- **/ (LVM)**:  
  - **root**, `mkfs.btrfs -L root /dev/mapper/archlinux-root`
  - **home**, `mkfs.btrfs -L home /dev/mapper/archlinux-home`
  - **swap**, `mkswap /dev/mapper/archlinux-swap`

Ora attiviamo anche la **swap**, questo serve per essere vista quando viene generato il file `/etc/fstab` tramite il comando [`genfstab`](https://wiki.archlinux.org/title/Genfstab) nel prossimo step.

```bash
swapon /dev/mapper/archlinux-swap
swapon -a
```

### 2.5 BtrFS

In questa fase montiamo e configuriamo i [subvolumes](https://wiki.archlinux.org/title/Btrfs#Subvolumes) e le [options](https://man.archlinux.org/man/core/btrfs-progs/btrfs.5.en#MOUNT_OPTIONS) per i volumi [**BtrFS**](https://wiki.archlinux.org/title/Btrfs) di **/** e **/home**.

La struttura di subvolumes studiata è la seguente:

```text
/
|__ /                  => @
|__ /.snapshots        => @snapshots
|__ /var
|   |__ /cache         => @cache
|   |__ /log           => @log
|   |__ /tmp           => @tmp
|   |__ /lib
|       |__ /flatpak   => @flatpak

/home
|__ /home              => @home
```

Alcune **options** consigliate:

- `noatime`, migliora le performance e riduce le scritture del SSD.
- `compress-force=zstd:1`, ottimale per i device **NVME**, Omettere il valore `:1` per usare il default `3`.
- `space_cache=v2`, crea una cache in memoria per migliorare le performance.

> [!TIP]
> Consiglio di creare una variabile che contine la stringa delle opzioni in modo da poterla usare ripetutamente nel corso di creazione dei vari **subvolumes**
>
> `export sv_opts="rw,noatime,compress-force=zstd:1,space_cache=v2"`

Per **/** creo i seguenti subvolumes:

- `snapshots`, contiene gli snapshots del sistema.
- `cache`, default della struttura linux.
- `log`, default della struttura linux.
- `tmp`, default della struttura linux.
- `flatpak`, contiene tutti i pacchetti flatpak che saranno disponibili **system-wide**.

```bash
mount /dev/mapper/archlinux-root /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@cache
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@tmp
btrfs subvolume create /mnt/@flatpak

umount /mnt

mount -o ${sv_opts},subvol=@ /dev/mapper/archlinux-root /mnt
mkdir -p /mnt/{.snapshots,var/cache,var/log,var/tmp,var/lib/flatpak}
mount -o ${sv_opts},subvol=@snapshots /dev/mapper/archlinux-root /mnt/.snapshots
mount -o ${sv_opts},subvol=@cache /dev/mapper/archlinux-root /mnt/var/cache
mount -o ${sv_opts},subvol=@log /dev/mapper/archlinux-root /mnt/var/log
mount -o ${sv_opts},subvol=@tmp /dev/mapper/archlinux-root /mnt/var/tmp
mount -o ${sv_opts},subvol=@flatpak /dev/mapper/archlinux-root /mnt/var/lib/flatpak
```

Procediamo analogamente per **/home**, dove creiamo l'ultimo subvolume rimasto, quello di `@home`

> [!NOTE]
> Usiamo il comando [`mount`](https://man.archlinux.org/man/mount.8) con l'opzione `--mkdir` per creare direttamente il mountpoint sul disco.

```bash
mount --mkdir /dev/mapper/archlinux-home /mnt/home
btrfs subvolume create /mnt/home/@home
umount /mnt/home
mount -o ${sv_opts},subvol=@home /dev/mapper/archlinux-home /mnt/home
```

### 2.6 Montaggio di EFI e /boot

Rispettivamente a come è stato indicato il layout del disco, montiamo le partizioni **EFI** e di **/boot** con il comando `mount`.

```bash
mount --mkdir /dev/sda2 /mnt/boot
mount --mkdir /dev/sda1 /mnt/efi
```

## 3 Installazione del Sistema Arch Linux

Ora si può installare il sistema **Arch Linux** sul disco configurato.

I seguenti pacchetti sono **OBBLIGATORI**:

- [`base`](https://wiki.archlinux.org/title/Arch_Linux#Base) e [`base-devel`](https://wiki.archlinux.org/title/Development_tools#Base-devel): Contengono i pacchetti base del sistema operativo e strumenti essenziali per la compilazione di software.
- [`linux-firmware`](https://wiki.archlinux.org/title/Linux#Firmware): Include i firmware necessari per l'hardware comune.
- [`linux-zen`](https://wiki.archlinux.org/title/Kernel#Linux_zen) e `linux-zen-headers`: Kernel Linux ottimizzato per performance e reattività. 
- `grub`, `efibootmgr` e `sbctl`:
  - [`grub`](https://wiki.archlinux.org/title/GRUB): Bootloader per gestire l'avvio del sistema operativo.
  - [`efibootmgr`](https://wiki.archlinux.org/title/EFISTUB#efibootmgr): Strumento per configurare i bootloader in modalità EFI.
  - [`sbctl`](https://wiki.archlinux.org/title/Secure_Boot#Using_sbctl): Strumento per gestire Secure Boot con chiavi personalizzate.
- [`networkmanager`](https://wiki.archlinux.org/title/NetworkManager): Strumento per configurare e gestire connessioni di rete.
- `btrfs-progs`, `cryptsetup` e `lvm2`:
  - [`btrfs-progs`](https://wiki.archlinux.org/title/Btrfs): Strumenti per la gestione di volumi BtrFS.
  - [`cryptsetup`](https://wiki.archlinux.org/title/Dm-crypt): Strumento per la gestione di dischi cifrati.
  - [`lvm2`](https://wiki.archlinux.org/title/LVM): Strumento per la gestione di volumi logici.

In aggiunta, è possibile installare altri pacchetti come:

- **CPU-ucode** (`intel-ucode` o `amd-ucode`): 
  - Microcodici specifici per processori Intel o AMD.
  - [Arch Wiki: Microcode](https://wiki.archlinux.org/title/Microcode)
- **Editor di Testo**:
  - Esempi: `vim`, `nano`, `neovim`.
  - Utili per modificare file di configurazione.
  - [Arch Wiki: Text Editors](https://wiki.archlinux.org/title/Text_editors)
- **Firewall**:
  - Esempio: `ufw` per configurare un firewall semplice.
  - [Arch Wiki: Firewall](https://wiki.archlinux.org/title/Simple_stateful_firewall#UFW)

> [!TIP]
> Consiglio di installare i pacchetti aggiuntivi di necessità nella fase di **configurazione**, quando si accede al sistema tramite `chroot`. Questo aiuta a mantenere il sistema privo di pacchetti non necessari (**bloat**).

Dopo l'installazione, genera il file `/etc/fstab` con il comando:

```bash
pacstrap -K /mnt base linux-zen linux-zen-headers linux-firmware btrfs-progs cryptsetup lvm2 networkmanager ufw grub efibootmgr sbctl
genfstab -U -p /mnt >> /mnt/etc/fstab
```


## 4 Entrare dentro il sistema appena installato

Questa operazione è facile ma al quanto importante per procedere con la **configurazione** del sistema e della guida.

Usando il comando [`arch-chroot`](https://man.archlinux.org/man/arch-chroot.8) dentro il mountpoint dove è stato montato il sistema, ovvero `mnt` (Vedi step 2.5 BtrFS, in particolare il comando `mount -o ${sv_opts},subvol=@ /dev/mapper/archlinux-root /mnt`).

``` bash
arch-chroot /mnt /bin/bash
```
