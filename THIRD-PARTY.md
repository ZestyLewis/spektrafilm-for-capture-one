# Third-party notices

Film Tools for Capture One is an independent project for a separately installed copy of Capture One. Capture One and the names of the upstream projects identify the software this project uses. The project has no affiliation with Capture One, Andrea Volpato, or Aedan Diez.

## spektrafilm OFX

The Vulkan renderer is built from Aedan Diez’s public spektrafilm OFX source at commit `86476afc5b077de77e2278e3658d1ba9309892a1`, with the changes recorded in [UPSTREAM-CHANGES.md](UPSTREAM-CHANGES.md). The [OFX source license](upstream-ofx/LICENSE.txt) is GNU GPL version 3. The renderer executable, compiled shaders, and runtime tables in the Windows release are built from the corresponding source and public inputs in this repository. The bundled OFX stock files retain their individual credits and license notices. See the [OFX source](https://github.com/chaert-s/spektrafilm-ofx/tree/86476afc5b077de77e2278e3658d1ba9309892a1) and [upstream third-party notices](upstream-ofx/Legal/THIRD_PARTY_NOTICES.txt).

The upstream [official binary notice](upstream-ofx/Legal/SPEKTRAFILM_OFX_LICENSE.txt) and [OFX-exported LUT license](upstream-ofx/Legal/SPEKTRAFILM_OFX_LUT_LICENSE.txt) are kept for reference. They cover upstream official packages and their exported LUTs. Film Tools builds its own renderer. The package omits the official OFX bundles, their presets, and the licensed SMPTE ST 2065-2 data required by Academy Printer Density.

The spectral reconstruction includes Johannes Hanika’s Hanatos 2025 work and an alternate reconstruction based on Mallett and Yuksel’s 2019 paper. The upstream notices link to the original work. [vkdt](https://github.com/hanatos/vkdt) · [Mallett and Yuksel](https://diglib.eg.org/items/bbffa865-e99c-4c1f-bd33-70102dc8af78)

## spektrafilm Python reference

The optional LUT worker uses the GPLv3 Python reference implementation by Andrea Volpato at commit `3bb2c2d2801ff68b92019cf1dbcbb133d60832bc`. The upstream [source license](upstream-spektrafilm/LICENSE), [citation metadata](upstream-spektrafilm/CITATION.cff), and [profile and LUT license](upstream-spektrafilm/SPEKTRAFILM_LICENSE.txt) accompany it. Its film profile JSONs and direct derivatives, including `.cube` files exported by this project’s optional Python worker, carry CC BY-SA 4.0 attribution to Andrea Volpato. If you share an exported LUT, retain its attribution, source and license links, and indicate changes. [spektrafilm reference source](https://github.com/andreavolpato/spektrafilm/tree/3bb2c2d2801ff68b92019cf1dbcbb133d60832bc) · [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)

## External dependencies

Builds use a locally installed Vulkan SDK and Visual Studio C++ toolchain. The panel builds against managed assemblies in the user’s Capture One installation. The distribution excludes those assemblies, Capture One SDK files, and Capture One camera ICC templates. The renderer uses the Vulkan loader supplied by the installed graphics drivers. The optional Python setup obtains Python packages from their package index. Those packages retain their own licenses and notices. No Python wheels, LLVM tools, standalone Vulkan SDK files, or Capture One components are redistributed here.
