# Spektrafilm for Capture One

<img src="assets/Spektrafilm.png" width="96" alt="Film strip icon with an orange viewfinder" />

An independent Windows tool that brings the spektrafilm film and print simulation into Capture One. Develop your RAW in Capture One, adjust the film look in a docked or floating panel, and export the result as a 16-bit image.

**Supported host: Capture One 16.4.6.2414 on Windows x64.** You'll also need a GPU and driver that support Vulkan. The launcher checks the exact Capture One build because the panel uses internal interfaces. This build works with catalogs (`.cocatalogdb`). Start with a test catalog when trying the integration.

Capture One provides older installers in your account when your license supports them. [Capture One download guide](https://support.captureone.com/hc/en-us/articles/14996282988957-Download-an-Older-Version-of-Capture-One)

## Install and open

1. Download **Spektrafilm-for-Capture-One-v0.1.1-windows-x64.zip** from [GitHub Releases](https://github.com/nothing-complex/spektrafilm-for-capture-one/releases/latest) and extract it.
2. Run **Install Spektrafilm for Capture One.cmd**. It installs under your Windows account and creates the **Spektrafilm for Capture One** desktop shortcut. A fresh install uses `%LOCALAPPDATA%\Programs\Spektrafilm for Capture One`.
3. Close Capture One. Use the new shortcut and choose the catalog database inside your catalog folder. The launcher backs up the closed database before opening it.
4. Select a photo and open the **Spektrafilm for Capture One** tab with the film-strip icon. Allow the Viewer to develop the first frame.

For portable use, run **Start Spektrafilm for Capture One.cmd** from the extracted folder and choose a catalog. Use that launcher or the desktop shortcut when you want to open Capture One with Spektrafilm.

To update, close Capture One and run the new release's installer. The installer updates the existing installation in place, replaces its desktop shortcut, and retains saved looks and the optional LUT environment. To verify the download, use `Get-FileHash -Algorithm SHA256` on the ZIP and compare the result with the `.sha256` file on the release page.

## Use the panel

- Turn **Enable Spektrafilm** on or off. The live look follows the selected photo and stays visible when you switch tool tabs. **Show source** temporarily displays the developed source for comparison.
- Select **Print Simulation** to pair a negative and print stock, or **Scan Film** to work from film alone. Use film exposure, print exposure and look strength to set the overall result. Double-click a slider to restore its default. The number fields accept direct entry.
- Expand the development, print, spectral reconstruction and optics sections for push/pull, dye and filter adjustments, halation, diffusion, scanner effects and grain. **Capture One Grain** applies a native adjustment when you click its Apply button.
- Choose **Float Tool** in the tool's three-dot menu. Close the floating tool to dock it again.
- Use **Viewer resolution** to select native size or a 720–4096 px long-edge cap. **Drag preview resolution** sets the temporary long edge while adjusting sliders. 1200 px is the starting value. Set it to 1600 or 2048 px for more detail, or lower either setting to reduce GPU work. The Viewer returns to its selected quality when the drag settles.
- In the color controls, pick the input working space Capture One develops into. Use sRGB to start, or choose Linear Rec.2020, ProPhoto RGB or Adobe RGB (1998). The renderer accepts that encoding and can display sRGB, Rec.709 gamma 2.4, or Linear Rec.709 in the Viewer. File exports are tagged sRGB. Capture One handles RAW development, camera profiles and its own adjustments.
- Use **Save preset** and **Load preset** in **Presets and LUT export** to retain a look and its controls.

## Saved looks

Spektrafilm automatically saves every change to the selected Capture One variant, including the enable switch, stocks, sliders, and preview settings. Each change is committed immediately, so Capture One can reopen the last complete save after a crash. Choose the same catalog through the desktop shortcut to restore its saved looks.

Saved looks live under `%LOCALAPPDATA%\FilmToolsForCaptureOne\Variant looks`. Back up that folder along with your catalog. Saved looks are associated with the catalog's path on this computer. Use **Save preset** to take a look to another catalog or computer.

## Export at 16 bits

With Spektrafilm enabled, select the photo and one enabled Export Recipe, then open Capture One's **Export** dialog. Confirm the export and choose **16-bit TIFF** or **16-bit PNG** in the Spektrafilm save dialog. The integration uses recipe sizing and crop where supported. The **Export with Spektrafilm** button in the panel also offers TIFF or PNG for the selected image. Source development and processing use high-depth channels through the 16-bit output encoder. **Save preview PNG** saves the on-screen comparison frame.

The export path is for the selected image with one recipe. It supports up to 32 megapixels and an 8192 px long edge. Reduce recipe size if the source would exceed those limits. Turn off **Enable Spektrafilm** to export through Capture One alone.

### Optional .cube export

Install 64-bit [Python 3.13](https://www.python.org/downloads/) and run **Setup LUT Export.cmd** in the installed folder. It creates a local environment and downloads the reference runtime's dependencies. Relaunch and choose a 33- or 65-point LUT from **Presets and LUT export**. The LUT uses sRGB input and output and represents the color transform. Keep the attribution in its header if you share it. [Profile and LUT license](upstream-spektrafilm/SPEKTRAFILM_LICENSE.txt)

## Troubleshooting and uninstall

| Symptom | What to do |
| --- | --- |
| The Spektrafilm tab is missing after restart | Close every Capture One window and launch again through **Spektrafilm for Capture One**. Open the catalog selected at launch. |
| Launcher reports a version mismatch | Select the x64 Capture One 16.4.6.2414 installation. |
| Viewer is slow | Select a smaller Viewer and drag-preview resolution. Lower the grain synthesis sample count if you are using synthesis. |
| Launcher finds an open or busy catalog | Open it in Capture One normally, close it, and retry. |
| GPU or startup error | Run `.\Start-Spektrafilm.ps1 -CheckOnly` in PowerShell from the installed folder. It checks the release files, Capture One build and a Vulkan test frame. |

Diagnostic logs and up to five database backups per catalog are under `%LOCALAPPDATA%\FilmToolsForCaptureOne`. The database backup covers the catalog database file. Keep your normal catalog and image backups as well.

To uninstall, close Capture One, delete the **Spektrafilm for Capture One** desktop shortcut, and remove the installation folder printed by the installer. Keep the saved looks and catalog backups under `%LOCALAPPDATA%\FilmToolsForCaptureOne` if you want to use them later. If you used portable mode, remove the extracted folder.

## Build from source

Building requires Windows x64, Visual Studio 2022 with Desktop development with C++, CMake 3.24 or newer, a Vulkan SDK, the .NET 8 SDK, 64-bit Python 3.13 and a local installation of Capture One 16.4.6.2414. The checked-in upstream snapshots contain the code and tables used in the build. From the repository in PowerShell, point `$python` to your Python 3.13 executable and run:

```powershell
& $python -m pip install -r .\requirements-build.txt
.\Build-Windows.ps1 -BuildPanel -StageRuntime -PythonPath $python
.\Start-Spektrafilm.ps1 -CheckOnly
.\Package-Windows.ps1 -Version 0.1.1
```

Use `-VulkanSdkPath` to specify a Vulkan SDK location or `-CaptureOneDirectory` for a custom Capture One installation. The build runs the renderer smoke test by default. Packaging writes the archive and SHA-256 checksum to `dist`. See the [upstream build and changes](UPSTREAM-CHANGES.md) and [third-party notices](THIRD-PARTY.md).

## Support development

- Capture One integration — [Luka Kauzlaric on Ko-fi](https://ko-fi.com/lukakauzlaric)
- Original spektrafilm research, simulation, and film profiles — [Andrea Volpato on Buy Me a Coffee](https://buymeacoffee.com/andreavolpato)
- spektrafilm OFX and Vulkan renderer — [Aedan Diez on Ko-fi](https://ko-fi.com/aedandiez)

## Credits

Andrea Volpato created the original spectral simulation and built the film profiles from real sensitometry and dye data. Aedan Diez built the Vulkan-powered OFX port that makes it practical to use the engine interactively. Both projects are worth exploring. [Andrea's spektrafilm](https://github.com/andreavolpato/spektrafilm) · [Aedan's spektrafilm OFX](https://spektrafilm.114c.de/)

Capture One integration by [Luka Kauzlaric](https://www.lukakauzlaric.com). I'm also building [Lensflare](https://www.lensflare.io).

Spektrafilm for Capture One is an unofficial integration developed independently of Capture One and the upstream authors. The integration is distributed under the GNU GPL v3. Film profiles and direct derivatives have separate CC BY-SA 4.0 terms. [GPL v3](LICENSE) · [Profile and LUT license](upstream-spektrafilm/SPEKTRAFILM_LICENSE.txt)
