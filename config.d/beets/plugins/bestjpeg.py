"""Encode resized cover art with the best available JPEG encoder.

Beets resizes through Pillow, which bundles libjpeg-turbo — correct, but it
leaves 10-30% on the table against a modern encoder at the same visual quality.
Art is embedded into *every* track of an album, so that multiplies.

Pillow still does the decode and Lanczos resample; it hands off a lossless PPM
and the external encoder does the only lossy step, so the image is compressed
exactly once. Non-JPEG targets and max_filesize (which runs its own quality
search) fall through to stock beets, as does having no encoder installed.
"""

import os
import shutil
import subprocess

from beets.plugins import BeetsPlugin
from beets.util import artresizer, get_temp_filename, syspath

# cjpegli (google/jpegli) beats cjpeg (mozjpeg) beats libjpeg-turbo. Homebrew's
# jpeg-xl builds with JPEGXL_ENABLE_JPEGLI=OFF, so cjpegli only appears if it
# was installed some other way — probe for it rather than depend on it.
ENCODERS = (
    ("cjpegli", lambda q, src, dst: ["-q", str(q), src, dst]),
    ("cjpeg", lambda q, src, dst: ["-quality", str(q), "-optimize",
                                   "-outfile", dst, src]),
)

EXTRA_PATH = "/opt/homebrew/opt/mozjpeg/bin"  # keg-only, not on PATH
JPEG_EXTS = (b".jpg", b".jpeg")


def _find_encoder():
    path = os.pathsep.join(p for p in (os.environ.get("PATH"), EXTRA_PATH) if p)
    for name, build_args in ENCODERS:
        exe = shutil.which(name, path=path)
        if exe:
            return exe, build_args
    return None, None


class BestJpegPlugin(BeetsPlugin):
    def __init__(self):
        super().__init__()
        self.exe, self.build_args = _find_encoder()
        if not self.exe:
            self._log.debug("no external JPEG encoder found; using Pillow")
            return
        self._log.debug("encoding cover art with {}", self.exe)

        original = artresizer.PILBackend.resize
        plugin = self

        def resize(backend, maxwidth, path_in, path_out=None, quality=0,
                   max_filesize=0):
            if not max_filesize:
                out = plugin._resize_and_encode(maxwidth, path_in, path_out,
                                                quality)
                if out is not None:
                    return out
            return original(backend, maxwidth, path_in, path_out, quality,
                            max_filesize)

        artresizer.PILBackend.resize = resize

    def _resize_and_encode(self, maxwidth, path_in, path_out, quality):
        """Return the encoded path, or None to fall back to stock beets."""
        if not path_out:
            path_out = get_temp_filename(__name__, "resize_bestjpeg_", path_in)
        if not os.path.splitext(path_out)[1].lower() in JPEG_EXTS:
            return None  # PNG stays PNG; don't silently make it lossy

        ppm = None
        try:
            from PIL import Image

            with Image.open(syspath(path_in)) as im:
                im.thumbnail((maxwidth, maxwidth), Image.Resampling.LANCZOS)
                if im.mode != "RGB":
                    im = im.convert("RGB")
                ppm = os.fsdecode(path_out) + ".ppm"
                im.save(ppm, format="PPM")

            args = self.build_args(quality or 95, ppm, os.fsdecode(path_out))
            subprocess.run([self.exe, *args], check=True, capture_output=True)
            return path_out
        except Exception as exc:
            self._log.debug("{} failed, falling back to Pillow: {}",
                            self.exe, exc)
            return None
        finally:
            if ppm and os.path.exists(ppm):
                os.remove(ppm)
