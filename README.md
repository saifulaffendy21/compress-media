# compress-media

A small Bash utility for batch-compressing Android phone photos and videos while retaining useful timestamps.

The script processes top-level `.jpg`, `.jpeg`, and `.mp4` files from one input folder and creates a sibling output folder named `<input-folder>-COMPRESSED`.

## Features

- Compresses JPEG photos at quality `85` without resizing them.
- Encodes MP4 video using H.265/HEVC (`libx265`), preset `ultrafast`, and CRF `28`.
- Encodes audio as AAC at `250 kbit/s`.
- Copies internal MP4 time metadata with ExifTool.
- Copies the original filesystem modified timestamp.
- Displays total, current, processed, pending, successful, skipped, and failed counts.
- Skips existing converted files but resynchronizes their timestamps.
- Supports uppercase and lowercase file extensions.

## Tested environment

This workflow has been tested with Android phone media on:

- Windows Subsystem for Linux (WSL)
- Ubuntu `20.04.6 LTS` (Focal Fossa)
- ImageMagick `6.9.10-23`, using the `convert` command

The script also detects the ImageMagick 7 `magick` command when available.

## Requirements

Install the required compression and metadata tools on Ubuntu:

```bash
sudo apt update
sudo apt install -y ffmpeg imagemagick libimage-exiftool-perl
```

Verify them:

```bash
ffmpeg -version
ffmpeg -hide_banner -encoders 2>/dev/null | grep libx265
convert -version || magick -version
exiftool -ver
```

## Installation

Clone the repository and make the script executable:

```bash
git clone https://github.com/saifulaffendy21/compress-media.git
cd compress-media
chmod +x compress-media.sh
```

## Usage

Pass the directory containing the media files:

```bash
./compress-media.sh "/mnt/d/android-backups/DCIM/Camera"
```

The script creates:

```text
/mnt/d/android-backups/DCIM/Camera-COMPRESSED
```

You may also start the script without an argument and enter the folder interactively:

```bash
./compress-media.sh
```

Show the built-in usage information:

```bash
./compress-media.sh --help
```

## Pull media from Android with ADB

ADB can copy a complete Android directory and its subdirectories to the computer. The `-a` option preserves the source file timestamp and mode.

### 1. Prepare the phone

1. Enable **Developer options** on the Android phone.
2. Enable **USB debugging**.
3. Connect the phone by USB.
4. Accept the USB debugging authorization message on the phone.

### 2. Install ADB on Ubuntu/WSL

```bash
sudo apt update
sudo apt install -y adb
```

Verify that the phone is authorized:

```bash
adb version
adb devices -l
```

The device status should be `device`, not `unauthorized`.

### 3. Pull DCIM to the Windows D: drive from WSL

Windows drives are mounted under `/mnt` in WSL. For example, `/mnt/d` is the Windows `D:` drive.

```bash
BACKUP_DIR="/mnt/d/android-backups/$(date +%Y-%m-%d)-DCIM"

mkdir -p "$BACKUP_DIR"
adb pull -a /sdcard/DCIM "$BACKUP_DIR"
```

The camera directory will normally be available at:

```text
$BACKUP_DIR/DCIM/Camera
```

Compress it with:

```bash
./compress-media.sh "$BACKUP_DIR/DCIM/Camera"
```

For additional ADB syntax, see the [official Android ADB documentation](https://developer.android.com/tools/adb) and [ADB command reference](https://android.googlesource.com/platform/packages/modules/adb/+/refs/heads/master/docs/user/adb.1.md).

## WSL USB note

If `adb devices` does not show the phone inside WSL, the USB device may not be attached to WSL. You can either:

- Attach the Android USB device to WSL using `usbipd-win`; or
- Run `adb.exe` from Windows PowerShell, save the backup on `D:`, and then run this compression script against the same directory through `/mnt/d`.

## Timestamp behavior

- JPEG outputs receive the original filesystem modified timestamp.
- MP4 outputs receive internal time metadata from the original video and the original filesystem modified timestamp.
- Linux `touch` does not change the Windows NTFS **Date created** field. Windows Explorer may therefore show the conversion time in the **Date created** column even when **Date modified** and **Media created** are preserved.

## Important notes

- Compression is lossy. Keep the original media until the output has been checked.
- Check video playback, audio, orientation, colour, and duration before deleting any source files.
- Some Android Ultra HDR JPEG files may contain an additional gain map that ordinary JPEG recompression may not preserve. Keep the original photos if Ultra HDR information is important.
- The script scans only the selected folder, not its subdirectories.
- Existing output files are not re-encoded.

## Validate the script

Run a Bash syntax check:

```bash
bash -n compress-media.sh
```
