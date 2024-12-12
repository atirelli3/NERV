![Arch Linux Logo](https://archlinux.org/static/logos/archlinux-logo-dark-scalable.518881f04ca9.svg)

# Arch Linux Installation Guide (by 7ir3)

The goal of this guide is to provide a **step-by-step** (or command-by-command) walkthrough to install a Linux system based on [Arch Linux](https://archlinux.org/) with a particular focus on system security and stability.

Each section will detail the reasoning behind the commands used. However, here is a brief overview of the system's key points:

- **Btrfs Filesystem**: The installation utilizes [**BtrFS**](https://wiki.archlinux.org/title/Btrfs) to ensure stability and the ability to roll back in case of issues. Thanks to its **snapshot** capabilities and the ability to split the system into **subvolumes**, BtrFS offers flexible and resilient filesystem management.
- **Partition Encryption**: The `/` and `/boot` partitions are encrypted to ensure maximum security and data protection in case of unauthorized physical access. This is crucial for laptops or enterprise systems.
- **Application Containerization**: The guide includes using tools like `flatpak` to manage applications in a containerized manner, both in the system and user environments. This approach improves application isolation and management, using [Flathub](https://flathub.org/) as the primary source.

TODO: index

---

## 0. Download the Arch Linux ISO Image and Create Bootable Media

TODO: write instructions on how to mount the ISO image to a USB drive from the terminal or using software.

## 1. Preparation and Configuration of the `archiso` ISO Image

The first tasks to perform upon booting into the Arch Linux installation image (`archiso`) involve configuring aspects like the **keyboard layout**, **locale**, and **pacman optimization** for a better installation experience.

> [!NOTE]
> If using a wireless connection, you need to connect the ISO image to the WiFi network. To do so, `archiso` includes the package [`iwd`](https://wiki.archlinux.org/title/Iwd), specifically using the command [`iwctl`](https://man.archlinux.org/man/iwctl.1) to connect to wireless networks.
>
> To connect to a specific network, run:
>
> ```bash
> iwctl --passphrase=PASSPHRASE station DEVICE connect SSID
> ```

Ensure that the [**kernel modules**](https://wiki.archlinux.org/title/Kernel_module) required for **disk encryption** and **mapping tools** are loaded into the kernel:

- [`dm-crypt`](https://wiki.archlinux.org/title/Dm-crypt)
- [`dm-mod`](https://docs.kernel.org/admin-guide/device-mapper/dm-init.html)

Additionally, remove the kernel module for the **speaker** to avoid noises or beeps during installation:

- [`pcspkr`](https://wiki.archlinux.org/title/PC_speaker)

```bash
modprobe dm-crypt
modprobe dm-mod
rmmod pcspkr
```

Proceed with the base configuration of `archiso`:

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
> The configuration of [`pacman`](https://wiki.archlinux.org/title/Pacman) has been automated using the [`sed`](https://man7.org/linux/man-pages/man1/sed.1.html) command.
>
> Alternatively, you can configure it manually using a text editor (e.g., `vim` or `nano`):
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

### 1.1 (Recommended!) SSH Configuration for Remote Installation

The steps below show how to enable [**SSH**](https://wiki.archlinux.org/title/OpenSSH) for remote system installation using your preferred host system.

> [!TIP]
> This step is highly recommended as it allows you to follow the guide more conveniently by executing commands with simple and practical **copy/paste**.

1. Set a password for the `root` user using the [`passwd`](https://man.archlinux.org/man/passwd.1) command:
   ```bash
   passwd
   ```

2. Enable the **SSH** service ([Daemon management](https://wiki.archlinux.org/title/OpenSSH#Daemon_management)):
   ```bash
   systemctl start sshd.service
   ```

3. Check the current IP address assigned to the machine:
   ```bash
   ip a
   ```

From your host machine, connect to the **target machine** using the command:

```bash
ssh root@IP
```

Enter the password chosen in step 1, and you are ready to proceed with the installation guide.

## 2. Disk Partitioning and Formatting

To ensure security through **encryption** and **segregation** of the system and applications (*system* and *user*), the disk will be partitioned with the following layout:

```text
/dev/sda

+-------+---------+-----------+
|       |         |           |
|  EFI  |  /boot  |  LVM (/)  |
|       |         |           |
+-------+---------+-----------+
```

> [!TIP]
> In this guide, `/dev/sda` is used as the reference for the target disk. Use the [`lsblk`](https://wiki.archlinux.org/title/Device_file#lsblk) command to identify the correct disk for system installation.

This layout allows encrypting the **/boot** and **/** partitions, leaving only the **EFI** partition unencrypted. The **EFI** partition must be clear to hold the **bootloader**, essential for booting the system. Later in the guide, the chosen bootloader will be specified along with relevant documentation references.

Using [**LVM**](https://wiki.archlinux.org/title/LVM) enables creating logical volumes, adding a level of **segregation** to the system. This allows separating the **/** partition from **/home**. The suggested layout for logical volumes is as follows:

```text
archlinux (or a chosen name for the logical physical volume created for /)

+------------------+------------------+------------------+
|                  |                  |                  |
|  archlinux-swap  |  archlinux-root  |  archlinux-home  |
|                  |                  |                  |
+------------------+------------------+------------------+
```

> [!NOTE]
> Recommended sizes for each **logical volume** in LVM will be indicated below.

### 2.1 Data Wipe and Disk Partitioning

It is necessary to **wipe** the disk of any existing data before formatting it into the three planned partitions.

For this operation, the [`wipefs`](https://man.archlinux.org/man/wipefs.8.en) and [`sgdisk`](https://man.archlinux.org/man/sgdisk.8.en) commands are used:

```bash
wipefs -af /dev/sda
sgdisk --zap-all --clear /dev/sda
```

> [!NOTE]
> After every disk operation that modifies data or the GPT partition tables, use the [`partprobe /dev/sda`](https://man.archlinux.org/man/partprobe.8.en) command to inform the **kernel** of the changes.

Now, format the disk into the **three partitions** required by the layout defined earlier:

- **EFI**: `sgdisk --set-alignment=4096 -n 1:0:+512M -t 1:ef00 /dev/sda`
- **/boot**: `sgdisk --set-alignment=4096 -n 2:0:+1G -t 2:8300 /dev/sda`
- **/**: `sgdisk --set-alignment=4096 -n 3:0:0 -t 3:8309 /dev/sda`

> [!TIP]
> Partition sizes can be adjusted based on personal needs. Here are some suggestions:
>
> - **EFI**: Recommended < 512M
> - **/boot**: Recommended between 1G and 5G
>
> The **/** partition will use the remaining disk space, accounting for the other partitions' sizes.

#### 2.1.1 (Optional) Zero-out Partitions

It is recommended to perform a **zero-out** procedure on each partition. This ensures that all partitions are cleared of residual data by writing zeros to each indicated partition:

```bash
cat /dev/zero > /dev/sda1
cat /dev/zero > /dev/sda2
cat /dev/zero > /dev/sda3
```

### 2.2 Disk Encryption

Proceed with encrypting the disk, specifically partition `3`, which contains **/**.

Use the [`cryptsetup`](https://man.archlinux.org/man/cryptsetup.8.en) tool, provided by the **dm-crypt** kernel module previously loaded into the system.

> [!IMPORTANT]
> When running the `echo` command piped with `cryptsetup`, a key value **changeme** is passed. Replace this value with a secure and personalized key. 
> Additionally, the encrypted partition is labeled as **cryptdev**. This label can also be customized. Replace the value in subsequent commands if you decide to change it. This label is used to map the encrypted disk using the previously loaded **dm-mod** kernel module.

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

As you can see, only partition `sda3` has been encrypted at this stage. The `sda2` partition (**/boot**) remains clear and will be encrypted later during the system image generation.

### 2.3 LVM

Create **logical volumes** in the **/** partition to align with the previously defined layout, separating the **root**, **home**, and **swap** partitions from one another.

> [!NOTE]
> The logical volume **master** is labeled **archlinux**. Depending on the chosen label, remember to modify references in subsequent commands for `LABEL-root`, `LABEL-home`, and `LABEL-swap`.

```bash
pvcreate /dev/mapper/cryptdev
vgcreate archlinux /dev/mapper/cryptdev
```

Create the volumes for each logical partition:

- **swap**, recommended size: **512M** or **RAM + 2G**:
  ```bash
  lvcreate -n swap -L 18G archlinux
  ```
- **root**, recommended size: between **50G** and **200G**, depending on disk size:
  ```bash
  lvcreate -n root -L 50G archlinux
  ```
- **home**, use the remaining disk space:
  ```bash
  lvcreate -n home -l +100%FREE archlinux
  ```

### 2.4 Partition Formatting

Format each previously created partition using the **filesystem** suitable for its usage and type, as defined during the disk partitioning stage.

Use the [`mkfs`](https://wiki.archlinux.org/title/File_systems#Create_a_file_system) command to create the desired filesystem. For **swap**, use the [`mkswap`](https://wiki.archlinux.org/title/Swap#Swap_partition) command.

- **EFI**, `mkfs.fat -F32 /dev/sda1`
- **/boot**, `mkfs.ext4 /dev/sda2`
- **/ (LVM)**:  
  - **root**, `mkfs.btrfs -L root /dev/mapper/archlinux-root`
  - **home**, `mkfs.btrfs -L home /dev/mapper/archlinux-home`
  - **swap**, `mkswap /dev/mapper/archlinux-swap`

Now activate **swap** so it is visible when generating the `/etc/fstab` file using the [`genfstab`](https://wiki.archlinux.org/title/Genfstab) command in the next step.

```bash
swapon /dev/mapper/archlinux-swap
swapon -a
```

### 2.5 BtrFS

At this stage, mount and configure the [subvolumes](https://wiki.archlinux.org/title/Btrfs#Subvolumes) and [options](https://man.archlinux.org/man/core/btrfs-progs/btrfs.5.en#MOUNT_OPTIONS) for the [**BtrFS**](https://wiki.archlinux.org/title/Btrfs) volumes for **/** and **/home**.

The planned subvolume structure is as follows:

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

Some recommended **options**:

- `noatime`, improves performance and reduces SSD write operations.
- `compress-force=zstd:1`, optimal for **NVME** devices. Omit the `:1` value to use the default `3`.
- `space_cache=v2`, creates an in-memory cache to enhance performance.

> [!TIP]
> It is recommended to create a variable containing the options string for repeated use when creating the various **subvolumes**.
>
> `export sv_opts="rw,noatime,compress-force=zstd:1,space_cache=v2"`

For **/** create the following subvolumes:

- `snapshots`, contains system snapshots.
- `cache`, default Linux structure.
- `log`, default Linux structure.
- `tmp`, default Linux structure.
- `flatpak`, contains all system-wide flatpak packages.

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

Proceed similarly for **/home**, creating the remaining subvolume, `@home`.

> [!NOTE]
> Use the [`mount`](https://man.archlinux.org/man/mount.8) command with the `--mkdir` option to directly create the mountpoint on the disk.

```bash
mount --mkdir /dev/mapper/archlinux-home /mnt/home
btrfs subvolume create /mnt/home/@home
umount /mnt/home
mount -o ${sv_opts},subvol=@home /dev/mapper/archlinux-home /mnt/home
```

### 2.6 Mounting EFI and /boot

According to the disk layout, mount the **EFI** and **/boot** partitions using the `mount` command.

```bash
mount --mkdir /dev/sda2 /mnt/boot
mount --mkdir /dev/sda1 /mnt/efi
```

## 3 Installing Arch Linux System

Now you can install the **Arch Linux** system onto the configured disk.

The following packages are **MANDATORY**:

- [`base`](https://wiki.archlinux.org/title/Arch_Linux#Base) and [`base-devel`](https://wiki.archlinux.org/title/Development_tools#Base-devel): Contain the essential base packages of the operating system and tools for software compilation.
- [`linux-firmware`](https://wiki.archlinux.org/title/Linux#Firmware): Provides firmware required for common hardware.
- [`linux-zen`](https://wiki.archlinux.org/title/Kernel#Linux_zen) and `linux-zen-headers`: A Linux kernel optimized for performance and responsiveness. 
- `grub`, `efibootmgr`, and `sbctl`:
  - [`grub`](https://wiki.archlinux.org/title/GRUB): A bootloader to manage the operating system startup.
  - [`efibootmgr`](https://wiki.archlinux.org/title/EFISTUB#efibootmgr): A tool for configuring bootloaders in EFI mode.
  - [`sbctl`](https://wiki.archlinux.org/title/Secure_Boot#Using_sbctl): A utility for managing Secure Boot with custom keys.
- [`networkmanager`](https://wiki.archlinux.org/title/NetworkManager): A tool for configuring and managing network connections.
- `btrfs-progs`, `cryptsetup`, and `lvm2`:
  - [`btrfs-progs`](https://wiki.archlinux.org/title/Btrfs): Tools for managing Btrfs volumes.
  - [`cryptsetup`](https://wiki.archlinux.org/title/Dm-crypt): A utility for managing encrypted disks.
  - [`lvm2`](https://wiki.archlinux.org/title/LVM): A tool for managing logical volumes.

Additionally, you may install other packages such as:

- **CPU Microcode** (`intel-ucode` or `amd-ucode`): 
  - Specific microcodes for Intel or AMD processors.
  - [Arch Wiki: Microcode](https://wiki.archlinux.org/title/Microcode)
- **Text Editors**:
  - Examples: `vim`, `nano`, `neovim`.
  - Useful for editing configuration files.
  - [Arch Wiki: Text Editors](https://wiki.archlinux.org/title/Text_editors)
- **Firewall**:
  - Example: `ufw` for simple firewall configuration.
  - [Arch Wiki: Firewall](https://wiki.archlinux.org/title/Simple_stateful_firewall#UFW)

> [!TIP]
> It is recommended to install additional packages during the **configuration** phase, when accessing the system through `chroot`. This helps keep the system free of unnecessary packages (**bloat**).

After installation, generate the `/etc/fstab` file with the following command:

```bash
pacstrap -K /mnt base linux-zen linux-zen-headers linux-firmware btrfs-progs cryptsetup lvm2 networkmanager ufw grub efibootmgr sbctl
genfstab -U -p /mnt >> /mnt/etc/fstab
```

## 4 Accessing the Newly Installed System

This step is straightforward but crucial for proceeding with the **configuration** of the system and guide.

Use the [`arch-chroot`](https://man.archlinux.org/man/arch-chroot.8) command to access the mount point where the system has been installed, namely `mnt` (see step 2.5 BtrFS, particularly the command `mount -o ${sv_opts},subvol=@ /dev/mapper/archlinux-root /mnt`).

```bash
arch-chroot /mnt /bin/bash
```
