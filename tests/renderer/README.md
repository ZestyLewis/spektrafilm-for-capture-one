# Renderer contracts

Run without Capture One, Python, the film data or a GPU:

```powershell
dotnet run --project tests/renderer/RendererContracts.csproj -c Release
```

This links the production managed renderer client and LUT exporter into a fake-worker test executable. Each case gets a disposable fixture below its ignored build-output folder. It checks malformed and truncated responses, incompatible capabilities, process replacement, valid error recovery, source reuse and changed shape, cancellation before/during transport, serialization of simultaneous requests, child-only environment isolation, malformed/mismatched release manifests, LUT options/exclusions, finite sample validation, grid order, and linear-light strength blending. It neither launches nor edits Capture One.

For a built source/runtime folder whose `renderer` subfolder contains the current native executable, shader folder and `.f32` resources:

```powershell
dotnet run --project tests/renderer/RendererContracts.csproj -c Release -- --gpu C:\path\to\Spektrafilm
python ofx-still-renderer/smoke.py --exe C:\path\to\Spektrafilm\renderer\SpektraStillRenderer.exe
```

The GPU contracts call the production managed client. They check negotiated diagnostics, unchanged-request cache reuse, byte-identical production output with an inherited `SPEKTRAFILM_VULKAN_COPY_PASS=1`, and 33/65-point LUT samples against a separate rendering of the same colour-only grid. The smoke suite covers persistent streams, invalid requests, export limits, output transfer functions and spatial/development effects. These synthetic probes do not establish camera/input-profile fidelity or performance on another GPU.

Protocol 1 uses little-endian eight-byte status/payload-length headers. `HELLO 1` replies with bounded UTF-8 JSON identifying float32 RGBA, byte order, dimensions, packed-display availability, and SHA-256 of the parameter header. `METRICS` replies with diagnostics schema 1. Neither command starts the Vulkan device. Legacy frame commands remain accepted by the native worker, but the current panel requires negotiation so mismatched installations fail before rendering. Packaged launchers additionally verify resource file hashes; a parameter-header fingerprint alone does not identify the entire renderer/resource build.
